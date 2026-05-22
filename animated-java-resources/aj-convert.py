import os
import sys
import nbtlib

DEFAULT_OFFSETS = {
    "head": 0.0,
    "right_arm": -1024.0,
    "left_arm": -2048.0,
    "torso": -3072.0,
    "right_leg": -4096.0,
    "left_leg": -5120.0,
}

SPLIT_OFFSETS = {
    "head": 0.0,
    "right_arm": -1024.0,
    "right_forearm": -6144.0,
    "left_arm": -2048.0,
    "left_forearm": -7168.0,
    "torso": -3072.0,
    "waist": -8192.0,
    "right_leg": -4096.0,
    "lower_right_leg": -9216.0,
    "left_leg": -5120.0,
    "lower_left_leg": -10240.0,
}

TY_IDX = 7


def parse_cli_arguments():
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)

    project = sys.argv[1]
    player_name = ""
    offsets = DEFAULT_OFFSETS

    for arg in sys.argv[2:]:
        if arg.startswith("-pn="):
            player_name = arg[4:]
        elif arg == "-split":
            offsets = SPLIT_OFFSETS

    return project, player_name, offsets


def print_usage():
    print("Usage: aj-convert-clean.py [project] [optional:flags]")
    print("  -pn=[playerName]   Player skin to use (default: none -> air)")
    print("  -split             Enable split model mode")


def is_flat_matrix(transformation):
    return isinstance(transformation, (nbtlib.List, list)) and len(transformation) == 16


def is_compound_translation(transformation):
    return isinstance(transformation, nbtlib.Compound) and "translation" in transformation


def add_y_offset(transformation, y_offset):
    if is_flat_matrix(transformation):
        transformation[TY_IDX] = nbtlib.tag.Float(float(transformation[TY_IDX]) + y_offset)
    elif is_compound_translation(transformation):
        transformation["translation"][1] = nbtlib.tag.Float(
            float(transformation["translation"][1]) + y_offset
        )
    else:
        raise TypeError(f"Unexpected transformation type: {type(transformation)}")


def modify_summon_file(filepath, project, offsets, player_name):
    if not os.path.isfile(filepath):
        return

    with open(filepath, "r", encoding="utf-8") as f:
        raw_lines = f.readlines()

    for i, line in enumerate(raw_lines):
        if "Passengers" not in line:
            continue

        try:
            nbt_start = line.index("~ ~ ~") + len("~ ~ ~")
            while nbt_start < len(line) and line[nbt_start] == " ":
                nbt_start += 1
        except ValueError:
            continue

        nbt_data = line[nbt_start:]
        if len(nbt_data) >= 4 and nbt_data[-4] == ",":
            nbt_data = nbt_data[:-4] + nbt_data[-3:]

        cut_marker = "], CustomName:"
        suffix = ""
        nbt_parseable = nbt_data

        if cut_marker in nbt_data:
            cut_idx = nbt_data.index(cut_marker)
            nbt_parseable = nbt_data[:cut_idx + 1] + " }"
            suffix = ", CustomName:" + nbt_data[cut_idx + len(cut_marker):]

        try:
            nbt_root = nbtlib.parse_nbt(nbt_parseable)
        except Exception:
            try:
                nbt_root = nbtlib.parse_nbt(nbt_data)
                suffix = ""
            except Exception:
                continue

        if "Passengers" not in nbt_root or len(nbt_root["Passengers"]) < 1:
            continue

        update_nbt_passengers(nbt_root, project, offsets, player_name)

        serialized = nbtlib.serialize_tag(nbt_root, compact=True)
        final_nbt = (serialized[:-1] + suffix) if suffix else serialized
        raw_lines[i] = line[:nbt_start] + final_nbt + "\n"

        with open(filepath, "w", encoding="utf-8") as f:
            f.writelines(raw_lines)
        return


def get_current_y(transform):
    if is_flat_matrix(transform):
        return float(transform[TY_IDX])
    if is_compound_translation(transform):
        return float(transform["translation"][1])
    return 0.0


def set_y(transform, y_value):
    if is_flat_matrix(transform):
        transform[TY_IDX] = nbtlib.tag.Float(y_value)
    elif is_compound_translation(transform):
        transform["translation"][1] = nbtlib.tag.Float(y_value)


def update_nbt_passengers(nbt_root, project, offsets, player_name):
    for passenger in nbt_root["Passengers"]:
        tags = passenger.get("Tags", [])

        for bone_name, offset in offsets.items():
            tag_new = f"aj.{project}.bone.{bone_name}"
            tag_old = f"animated_java.{project}.bone.{bone_name}"

            if tag_new not in tags and tag_old not in tags:
                continue

            transform = passenger.get("transformation")
            if transform is not None and offset != 0.0:
                current_y = get_current_y(transform)
                if abs(current_y) < 0.01:
                    set_y(transform, offset)

            passenger["item_display"] = nbtlib.tag.String("thirdperson_righthand")

            if "item" not in passenger:
                passenger["item"] = nbtlib.Compound()

            passenger["item"]["id"] = nbtlib.tag.String(
                "minecraft:player_head" if player_name else "minecraft:air"
            )

            if player_name:
                if "components" not in passenger["item"]:
                    passenger["item"]["components"] = nbtlib.Compound()
                passenger["item"]["components"]["minecraft:profile"] = nbtlib.Compound(
                    {"name": nbtlib.tag.String(player_name)}
                )


def update_pose_and_frame_files(base_path, offsets):
    candidates = []

    for dirpath, _, filenames in os.walk(base_path):
        for fname in filenames:
            if not fname.endswith(".mcfunction"):
                continue

            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue

            for bone_name in offsets:
                if f"$({bone_name})" in content or f"$(bone_{bone_name})" in content:
                    candidates.append(fpath)
                    break

    for path in candidates:
        try:
            with open(path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            new_lines = [modify_macro_line(line, offsets) for line in lines]

            if new_lines != lines:
                with open(path, "w", encoding="utf-8") as f:
                    f.writelines(new_lines)
        except Exception:
            pass


def modify_macro_line(line, offsets):
    for bone_name, offset in offsets.items():
        for macro in (f"$({bone_name})", f"$(bone_{bone_name})"):
            if macro in line:
                return patch_macro_nbt(line, offset, macro)
    return line


def patch_macro_nbt(line, y_offset, macro):
    try:
        start = line.index(macro) + len(macro)
        brace = line.index("{", start)
    except ValueError:
        return line

    head = line[:brace]
    tail = line[brace:]

    try:
        nbt_root = nbtlib.parse_nbt(tail)
    except Exception:
        try:
            nbt_root = nbtlib.parse_nbt(tail.rstrip())
        except Exception:
            return line

    if "transformation" not in nbt_root:
        return line

    try:
        add_y_offset(nbt_root["transformation"], y_offset)
    except Exception:
        return line

    return head + nbtlib.serialize_tag(nbt_root, compact=True) + "\n"


def main():
    project, player_name, offsets = parse_cli_arguments()

    base = None
    for namespace in ("aj", "animated_java"):
        candidate = os.path.join(".", "data", namespace, "function", project)
        if os.path.isdir(candidate):
            base = candidate
            break

    if base is None:
        print(f"Project folder not found under data/{{aj,animated_java}}/function/{project}")
        sys.exit(1)

    modify_summon_file(os.path.join(base, "summon.mcfunction"), project, offsets, player_name)
    update_pose_and_frame_files(base, offsets)


if __name__ == "__main__":
    main()
