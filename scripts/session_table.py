import argparse
import datetime
import shutil
import textwrap
import zoneinfo


COLUMN_LIMITS = (
    ("project", 24),
    ("task id", 36),
    ("title", 60),
    ("created", 21),
    ("last updated", 21),
)

COLUMN_GROWTH_BANDS = (
    (7, 8, 5, 7, 12),
    (10, 12, 16, 11, 12),
    (10, 12, 16, 21, 21),
    (16, 24, 28, 21, 21),
    (24, 36, 60, 21, 21),
)

WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
MONTHS = (
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
)


def positive_integer(value):
    try:
        count = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("count must be a positive integer") from error

    if count < 1:
        raise argparse.ArgumentTypeError("count must be a positive integer")
    return count


def timezone(value):
    try:
        return zoneinfo.ZoneInfo(value)
    except zoneinfo.ZoneInfoNotFoundError as error:
        raise argparse.ArgumentTypeError(f"unknown timezone: {value}") from error


def normalized_text(value, fallback):
    printable = "".join(
        character if character.isprintable() else " " for character in str(value)
    )
    text = " ".join(printable.split())
    return text or fallback


def local_timestamp(milliseconds, selected_timezone):
    instant = datetime.datetime.fromtimestamp(
        int(milliseconds) / 1000,
        tz=datetime.timezone.utc,
    )
    if selected_timezone is None:
        instant = instant.astimezone()
    else:
        instant = instant.astimezone(selected_timezone)
    return (
        f"{WEEKDAYS[instant.weekday()]} {MONTHS[instant.month - 1]} "
        f"{instant.day:02d} {instant.year:04d} {instant:%H:%M}"
    )


def columns(id_header):
    return (
        COLUMN_LIMITS[0],
        (id_header, COLUMN_LIMITS[1][1]),
        *COLUMN_LIMITS[2:],
    )


def grow_widths(widths, preferred, targets, remaining):
    order = (2, 0, 1, 3, 4)
    while remaining:
        grew = False
        for index in order:
            target = min(preferred[index], targets[index])
            if widths[index] >= target:
                continue
            widths[index] += 1
            remaining -= 1
            grew = True
            if not remaining:
                break
        if not grew:
            break
    return remaining


def table_widths(rows, terminal_width, table_columns):
    preferred = []
    for index, (header, maximum) in enumerate(table_columns):
        widest = max([len(header), *(len(row[index]) for row in rows)])
        preferred.append(min(maximum, widest))

    frame_width = 3 * len(table_columns) + 1
    available = max(len(table_columns), terminal_width - frame_width)
    widths = [1] * len(table_columns)
    remaining = available - len(table_columns)
    for targets in COLUMN_GROWTH_BANDS:
        remaining = grow_widths(widths, preferred, targets, remaining)
        if not remaining or widths == preferred:
            break
    return widths


def wrapped_cell(value, width):
    return textwrap.wrap(
        value,
        width=width,
        break_long_words=True,
        break_on_hyphens=False,
    ) or [""]


def rendered_row(values, widths):
    cells = [wrapped_cell(value, width) for value, width in zip(values, widths)]
    height = max(len(cell) for cell in cells)
    lines = []
    for line_number in range(height):
        parts = []
        for cell, width in zip(cells, widths):
            value = cell[line_number] if line_number < len(cell) else ""
            parts.append(f" {value:<{width}} ")
        lines.append(f"|{'|'.join(parts)}|")
    return lines


def rendered_table(rows, terminal_width, id_header="task id"):
    table_columns = columns(id_header)
    headers = tuple(header for header, _ in table_columns)
    widths = table_widths(rows, terminal_width, table_columns)
    border = f"+{'+'.join('-' * (width + 2) for width in widths)}+"
    lines = [border, *rendered_row(headers, widths), border]
    for row in rows:
        lines.extend(rendered_row(row, widths))
        lines.append(border)
    return "\n".join(lines)


def rendered_terminal_table(rows, id_header="task id"):
    terminal_width = shutil.get_terminal_size(fallback=(160, 24)).columns
    return rendered_table(rows, terminal_width, id_header)
