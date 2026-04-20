# This is a port of the (very simple) Kilo text editor by antirez, to planet
# https://github.com/antirez/kilo - see copyright at the bottom of this file

# Kilo -- A very simple editor in less than 1-kilo lines of code (as counted
#         by "cloc"). Does not depend on libcurses, directly emits VT100
#         escapes on the terminal.

m4_define(KILO_VERSION, `"0.0.1-planet"')m4_dnl

use "ctype"
use "errno"
use "stdio"
use "stdlib"
use "string"
use "time"
use "signal"

# Syntax highlight types
m4_define(HL_NORMAL, 0)m4_dnl
m4_define(HL_NONPRINT, 1)m4_dnl
m4_define(HL_COMMENT, 2)m4_dnl # Single line comment.
m4_define(HL_MLCOMMENT, 3)m4_dnl # Multi-line comment.
m4_define(HL_KEYWORD1, 4)m4_dnl
m4_define(HL_KEYWORD2, 5)m4_dnl
m4_define(HL_STRING, 6)m4_dnl
m4_define(HL_NUMBER, 7)m4_dnl
m4_define(HL_MATCH, 8)m4_dnl # Search match.

m4_define(HL_HIGHLIGHT_STRINGS, 1)m4_dnl # (1 << 0)
m4_define(HL_HIGHLIGHT_NUMBERS, 2)m4_dnl # (1 << 1)

type struc editorSyntax(
    filematch: [6]string,
    keywords: [82]string,
    singleline_comment_start: [2]char,
    multiline_comment_start: [3]char,
    multiline_comment_end: [3]char,
    flags: i32
)

# This structure represents a single line of the file we are editing.
type struc erow(
    idx: i32, # Row index in the file, zero-based.
    size: i32, # Size of the row, excluding the null term.
    rsize: i32, # Size of the rendered row.
    chars: string, # Row content.
    render: string, # Row content "rendered" for screen (for TABs).
    hl: *u8, # Syntax highlight type for each character in render.
    hl_oc: bool # Row had open comment at end in last syntax highlight check.
)

type struc editorConfig(
    cx: i32, # Cursor x and y position in characters
    cy: i32,
    rowoff: i32, # Offset of row displayed.
    coloff: i32, # Offset of column displayed.
    screenrows: i32, # Number of rows that we can show
    screencols: i32, # Number of cols that we can show
    numrows: i32, # Number of rows
    rawmode: bool, # Is terminal raw mode enabled?
    row: *struc erow, # Rows
    dirty: bool, # File modified but not saved.
    filename: string, # Currently open filename
    statusmsg: [80]char,
    statusmsg_time: u64,
    syntax: *struc editorSyntax # Current syntax highlight, or NULL.
)

E: struc editorConfig;

# KEY_ACTION
m4_define(KEY_NULL, 0)m4_dnl # NULL
m4_define(CTRL_C, 3)m4_dnl # Ctrl-c
m4_define(CTRL_D, 4)m4_dnl # Ctrl-d
m4_define(CTRL_F, 6)m4_dnl # Ctrl-f
m4_define(CTRL_H, 8)m4_dnl # Ctrl-h
m4_define(TAB, 9)m4_dnl # Tab
m4_define(CTRL_L, 12)m4_dnl # Ctrl+l
m4_define(ENTER, 13)m4_dnl # Enter
m4_define(CTRL_Q, 17)m4_dnl # Ctrl-q
m4_define(CTRL_S, 19)m4_dnl # Ctrl-s
m4_define(CTRL_U, 21)m4_dnl # Ctrl-u
m4_define(ESC, 27)m4_dnl # Escape
m4_define(BACKSPACE, 127)m4_dnl # Backspace
# The following are just soft codes, not really reported by the
# terminal directly.
m4_define(ARROW_LEFT, 1000)m4_dnl
m4_define(ARROW_RIGHT, 1001)m4_dnl
m4_define(ARROW_UP, 1002)m4_dnl
m4_define(ARROW_DOWN, 1003)m4_dnl
m4_define(DEL_KEY, 1004)m4_dnl
m4_define(HOME_KEY, 1005)m4_dnl
m4_define(END_KEY, 1006)m4_dnl
m4_define(PAGE_UP, 1007)m4_dnl
m4_define(PAGE_DOWN, 1008)m4_dnl

fn editorSetStatusMessage(format: string) none;

# =========================== POSIX header bindings ========================

# termios.h
type struc termios(
    c_iflag: u32, # input mode flags
    c_oflag: u32, # output mode flags
    c_cflag: u32, # control mode flags
    c_lflag: u32, # local mode flags
    c_line: u8, # line discipline
    c_cc: [32]u8, # control characters
    c_ispeed: u32, # input speed
    c_ospeed: u32 # output speed
)
extrn fn tcsetattr(fd: i32, optional_actions: i32, termios_p: *struc termios) i32;
extrn fn tcgetattr(fd: i32, termios_p: *struc termios) i32;
m4_define(TCSAFLUSH, 2)m4_dnl
m4_define(BRKINT, 2)m4_dnl # 0000002 Signal interrupt on break.
m4_define(INPCK, 16)m4_dnl # 0000020 Enable input parity check.
m4_define(ISTRIP, 32)m4_dnl # 0000040 Strip 8th bit off characters.
m4_define(ICRNL, 256)m4_dnl # 0000400 Map CR to NL on input.
m4_define(IXON, 1024)m4_dnl # 0002000 Enable start/stop output control.
m4_define(OPOST, 1)m4_dnl # 0000001 Post-process output.
m4_define(CS8, 48)m4_dnl # 0000060
m4_define(ECHO, 8)m4_dnl # 0000010 Enable echo.
m4_define(ICANON, 2)m4_dnl # 0000002 Canonical input (erase and kill processing).
m4_define(IEXTEN, 32768)m4_dnl # 0100000 Enable implementation-defined input processing.
m4_define(ISIG, 1)m4_dnl # 0000001 Enable signals.
m4_define(VTIME, 5)m4_dnl
m4_define(VMIN, 6)m4_dnl

# errno.h
m4_define(ENOENT, 2)m4_dnl # No such file or directory
m4_define(ENOTTY, 25)m4_dnl # Not a typewriter

# stdio.h
# _POSIX_C_SOURCE 200809L
extrn fn getline(lineptr: *string, n: *u64, stream: *struc FILE) i64;

# sys/ioctl.h
type struc winsize(
    ws_row: [2]u8,
    ws_col: [2]u8,
    ws_xpixel: [2]u8,
    ws_ypixel: [2]u8
)
extrn fn ioctl(fd: i32, request: u64, ws: *struc winsize) i32;
m4_define(TIOCGWINSZ, 21523)m4_dnl # 0x5413

# unistd.h
extrn fn isatty(fd: i32) i32;
extrn fn read(fd: i32, buf: *any, nbytes: u64) i64;
extrn fn write(fd: i32, buf: *any, n: u64) i64;
extrn fn ftruncate(fd: i32, length: i64) i32;
extrn fn close(fd: i32) i32;
m4_define(STDIN_FILENO, 0)m4_dnl # Standard input.
m4_define(STDOUT_FILENO, 1)m4_dnl # Standard output.

# fcntl.h
extrn fn open(path: string, oflag: i32, mode: u32) i32;
m4_define(O_RDWR, 2)m4_dnl # 02
m4_define(O_CREAT, 64)m4_dnl # 0100
m4_define(COPYMODE, 420)m4_dnl # 0644

# signal.h
# Nonstandard signals found in all modern POSIX systems
# (including both BSD and Linux).
m4_define(SIGWINCH, 28)m4_dnl # Window size change (4.3 BSD, Sun).

# =========================== ANSI escape sequences ========================
# https://gist.github.com/ConnerWill/d4b6c776b509add763e17f9f113fd25b

x1b_prefix: [3]char = $(ESC, '[', nil)

x1b_move_cur_home: [4]char = $(ESC, '[', 'H', nil)
x1b_get_cur_pos: [5]char = $(ESC, '[', '6', 'n', nil)
x1b_show_cur: [7]char = $(ESC, '[', '?', '2', '5', 'h', nil)
x1b_hide_cur: [7]char = $(ESC, '[', '?', '2', '5', 'l', nil)
x1b_erase_cur: [5]char = $(ESC, '[', '0', 'K', nil)
x1b_erase_cur_crlf: [7]char = $(ESC, '[', '0', 'K', '\r', '\n', nil)
x1b_put_blank_line: [8]char = $('~', ESC, '[', '0', 'K', '\r', '\n', nil)

x1b_set_inv_mode: [5]char = $(ESC, '[', '7', 'm', nil)
x1b_reset_modes: [5]char = $(ESC, '[', '0', 'm', nil)
x1b_reset_modes_clrf: [7]char = $(ESC, '[', '0', 'm', '\r', '\n', nil)

x1b_set_def_fgcol: [6]char = $(ESC, '[', '3', '9', 'm', nil)
x1b_get_ws_rowcol: [13]char = $(ESC, '[', '9', '9', '9', 'C', ESC, '[', '9', '9', '9', 'B', nil)

# =========================== Syntax highlights DB =========================
# 
# In order to add a new syntax, define two arrays with a list of file name
# matches and keywords. The file name matches are used in order to match
# a given syntax with a given file name: if a match pattern starts with a
# dot, it is matched as the last past of the filename, for example ".c".
# Otherwise the pattern is just searched inside the filenme, like "Makefile").
# 
# The list of keywords to highlight is just a list of words, however if they
# a trailing '|' character is added at the end, they are highlighted in
# a different color, so that you can have two different sets of keywords.
# 
# Finally add a stanza in the HLDB global variable with two two arrays
# of strings, and a set of flags in order to enable highlighting of
# comments and numbers.
# 
# The characters for single and multi line comments must be exactly two
# and must be provided as well (see the C language example).
# 
# There is no support to highlight patterns currently.

# C / C++
# Here we define an array of syntax highlights by extensions, keywords,
# comments delimiters and flags.
m4_define(HLDB_ENTRIES, 1)m4_dnl
HLDB: [HLDB_ENTRIES]struc editorSyntax = $($(
    # C_HL_extensions
    $(".c", ".h", ".cpp", ".hpp", ".cc", nil),
    # C_HL_keywords
    $(
    # C Keywords
    "auto", "break", "case", "continue", "default", "do", "else", "enum",
    "extern", "for", "goto", "if", "register", "return", "sizeof", "static",
    "struct", "switch", "typedef", "union", "volatile", "while", "NULL", 
    # C++ Keywords
    "alignas", "alignof", "and", "and_eq", "asm", "bitand", "bitor", "class",
    "compl", "constexpr", "const_cast", "deltype", "delete", "dynamic_cast",
    "explicit", "export", "false", "friend", "inline", "mutable", "namespace",
    "new", "noexcept", "not", "not_eq", "nullptr", "operator", "or", "or_eq",
    "private", "protected", "public", "reinterpret_cast", "static_assert",
    "static_cast", "template", "this", "thread_local", "throw", "true", "try",
    "typeid", "typename", "virtual", "xor", "xor_eq", 
    # C types
    "int|", "long|", "double|", "float|", "char|", "unsigned|", "signed|",
    "void|", "short|", "auto|", "const|", "bool|",
    nil),
    "//", "/*", "*/", m4_eval(HL_HIGHLIGHT_STRINGS | HL_HIGHLIGHT_NUMBERS)))

# ======================= Low level terminal handling ======================

orig_termios: struc termios; # In order to restore at exit.

fn disableRawMode(fd: i32) none {
    # Don't even check the return value as it's too late.
    if E.rawmode {
        tcsetattr(fd, TCSAFLUSH, @orig_termios)
        E.rawmode = false
    }
}

# Called at exit to avoid remaining in raw mode.
fn editorAtExit(none) none {
    disableRawMode(STDIN_FILENO)
}

pub fn atexit_func(none) none {
    editorAtExit()
}

# Raw mode: 1960 magic shit.
fn enableRawMode(fd: i32) i32 {
    raw: struc termios;

    if E.rawmode {
        return 0
    } # Already enabled.
    if not isatty(STDIN_FILENO) {
        jump fatal
    }
    atexit_f()
    if tcgetattr(fd, @orig_termios) == -1 {
        jump fatal
    }

    raw = orig_termios # modify the original mode
    # input modes: no break, no CR to NL, no parity check, no strip char,
    # no start/stop output control.
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
    # output modes - disable post processing
    raw.c_oflag &= ~(OPOST)
    # control modes - set 8 bit chars
    raw.c_cflag |= (CS8)
    # local modes - choing off, canonical off, no extended functions,
    # no signal chars (^Z,^C)
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG)
    # control chars - set return condition: min number of bytes and timer.
    raw.c_cc[VMIN] = 0 # Return each byte, or zero for timeout.
    raw.c_cc[VTIME] = 1 # 100 ms timeout (unit is tens of second).

    # put terminal in raw mode after flushing
    if tcsetattr(fd, TCSAFLUSH, @raw) < 0 {
        jump fatal
    }
    E.rawmode = true
    return 0

    label fatal
    set_errno(ENOTTY)
    return -1
}

# Read a key from the terminal put in raw mode, trying to handle
# escape sequences.
fn editorReadKey(fd: i32) i32 {
    nread: i32;
    c: char;
    seq: [3]char;
    loop while (nread = read(fd, @c, 1)) == 0;
    if nread == -1 {
        exit(1)
    }

    loop {
        match c {
            -> ESC { # escape sequence
                # If this is just an ESC, we'll timeout here.
                if read(fd, seq, 1) == 0 {
                    return ESC
                }
            }
            if read(fd, seq + 1, 1) == 0 {
                return ESC
            }

            # ESC [ sequences.
            if seq[0] == '[' {
                if seq[1] >= '0' and seq[1] <= '9' {
                    # Extended escape, read additional byte.
                    if read(fd, seq + 2, 1) == 0 {
                        return ESC
                    }
                    if seq[2] == '~' {
                        match seq[1] {
                            -> '3' {
                                return DEL_KEY
                            }
                            -> '5' {
                                return PAGE_UP
                            }
                            -> '6' {
                                return PAGE_DOWN
                            }
                        }
                    }
                }
                else {
                    match seq[1] {
                        -> 'A' {
                            return ARROW_UP
                        }
                        -> 'B' {
                            return ARROW_DOWN
                        }
                        -> 'C' {
                            return ARROW_RIGHT
                        }
                        -> 'D' {
                            return ARROW_LEFT
                        }
                        -> 'H' {
                            return HOME_KEY
                        }
                        -> 'F' {
                            return END_KEY
                        }
                    }
                }
            }

            # ESC O sequences.
            elif seq[0] == 'O' {
                match seq[1] {
                    -> 'H' {
                        return HOME_KEY
                    }
                    -> 'F' {
                        return END_KEY
                    }
                }
            }
            break
            otherwise {
                return c
            }
        }
    }
}

# Use the ESC [6n escape sequence to query the horizontal cursor position
# and return it. On error -1 is returned, on success the position of the
# cursor is stored at *rows and *cols and 0 is returned.
fn getCursorPosition(ifd: i32, ofd: i32, rows: *i32, cols: *i32) i32 {
    buf: [32]char;
    i: u32 = 0

    # Report cursor location
    if write(ofd, x1b_get_cur_pos, 4) ~= 4 {
        return -1
    }

    # Read the response: ESC [ rows ; cols R
    loop while i < sizeof(buf) - 1 {
        if read(ifd, buf + i, 1) ~= 1 {
            break
        }
        if buf[i] == 'R' {
            break
        }
        i++
    }
    buf[i] = nil

    # Parse it.
    if buf[0] ~= ESC or buf[1] ~= '[' {
        return -1
    }

    p: string = buf + 1
    loop while ++p and p[] {
        if p[] == ';' {
            p[] = 0
            if sscan(buf + 2, rows, "%d") ~= 1 {
                return -1
            }
            if sscan(p + 1, cols, "%d") ~= 1 {
                return -1
            }
            break
        }
    }
    return 0
}

# Try to get the number of columns in the current terminal. If the ioctl()
# call fails the function will try to query the terminal itself.
# Returns 0 on success, -1 on error.
fn getWindowSize(ifd: i32, ofd: i32, rows: *i32, cols: *i32) i32 {
    ws: struc winsize;

    if ioctl(1, TIOCGWINSZ, @ws) == -1 or (ws.ws_col[0] | ws.ws_col[1]) == 0 {
        # ioctl() failed. Try to query the terminal itself.
        orig_row: i32;
        orig_col: i32;
        retval: i32;

        # Get the initial position so we can restore it later.
        retval = getCursorPosition(ifd, ofd, @orig_row, @orig_col)
        if retval == -1 {
            jump failed
        }

        # Go to right/bottom margin and get position.
        if write(ofd, x1b_get_ws_rowcol, 12) ~= 12 {
            jump failed
        }
        retval = getCursorPosition(ifd, ofd, rows, cols)
        if retval == -1 {
            jump failed
        }

        # Restore position.
        seq: [32]char;
        sd: [2][20]char;
        snprint(seq, 32, fmt5(x1b_prefix, ltostr(sd[0], orig_row), ";", ltostr(sd[1], orig_col), "H"))
        if write(ofd, seq, strlen(seq)) == -1; # Can't recover...
        return 0
    }
    else {
        cols[] = ws.ws_col[0] + (cast<i32>(ws.ws_col[1]) << 8)
        rows[] = ws.ws_row[0] + (cast<i32>(ws.ws_row[1]) << 8)
        return 0
    }

    label failed
    return -1
}

# ====================== Syntax highlight color scheme  ====================

fn is_separator(c: i32) bool {
    return c == nil or isspace(c) or strchr(",.()+-/*=~%[];", c) ~= 0
}

# Return true if the specified row last char is part of a multi line comment
# that starts at this row or at one before, and does not end at the end
# of the row but spawns to the next row.
fn editorRowHasOpenComment(row: *struc erow) bool {
    if row[].hl and row[].rsize and row[].hl[row[].rsize - 1] == HL_MLCOMMENT and (row[].rsize < 2 or (row[].render[row[].rsize - 2] ~= '*' or row[].render[row[].rsize - 1] ~= '/')) {
        return true
    }
    return false
}

# Set every byte of row->hl (that corresponds to every character in the line)
# to the right syntax highlight type (HL_* defines).
fn editorUpdateSyntax(row: *struc erow) none {
    row[].hl = realloc(row[].hl, row[].rsize)
    memset(row[].hl, HL_NORMAL, row[].rsize)

    if E.syntax == nil {
        return none
    } # No syntax, everything is HL_NORMAL.

    i: i32;
    prev_sep: bool;
    in_string: bool;
    in_comment: bool;
    p: string;
    keywords: *string = E.syntax[].keywords
    scs: string = E.syntax[].singleline_comment_start
    mcs: string = E.syntax[].multiline_comment_start
    mce: string = E.syntax[].multiline_comment_end

    # Point to the first non-space char.
    p = row[].render
    i = 0 # Current char offset
    loop while p[] and isspace(p[]) {
        p++
        i++
    }
    prev_sep = true # Tell the parser if 'i' points to start of word.
    in_string = false # Are we inside "" or '' ?
    in_comment = false # Are we inside multi-line comment?

    # If the previous line has an open comment, this line starts
    # with an open comment state.
    if row[].idx > 0 and editorRowHasOpenComment(@E.row[row[].idx - 1]) {
        in_comment = true
    }

    loop while p[] {
        # Handle // comments.
        if prev_sep and p[] == scs[0] and (p + 1)[] == scs[1] {
            # From here to end is a comment
            memset(row[].hl + i, HL_COMMENT, row[].size - i)
            return none
        }

        # Handle multi line comments.
        if in_comment {
            row[].hl[i] = HL_MLCOMMENT
            if p[] == mce[0] and (p + 1)[] == mce[1] {
                row[].hl[i + 1] = HL_MLCOMMENT
                p += 2
                i += 2
                in_comment = false
                prev_sep = true
                continue
            }
            else {
                prev_sep = false
                p++
                i++
                continue
            }
        }
        elif p[] == mcs[0] and (p + 1)[] == mcs[1] {
            row[].hl[i] = HL_MLCOMMENT
            row[].hl[i + 1] = HL_MLCOMMENT
            p += 2
            i += 2
            in_comment = true
            prev_sep = false
            continue
        }

        # Handle "" and ''
        if in_string {
            row[].hl[i] = HL_STRING
            if p[] == '\\' {
                row[].hl[i + 1] = HL_STRING
                p += 2
                i += 2
                prev_sep = false
                continue
            }
            if p[] == in_string {
                in_string = false
            }
            p++
            i++
            continue
        }
        else {
            if p[] == '"' or p[] == '\'' {
                in_string = p[]
                row[].hl[i] = HL_STRING
                p++
                i++
                prev_sep = false
                continue
            }
        }

        # Handle non printable chars.
        if not isprint(p[]) {
            row[].hl[i] = HL_NONPRINT
            p++
            i++
            prev_sep = false
            continue
        }

        # Handle numbers
        if (isdigit(p[]) and (prev_sep or row[].hl[i - 1] == HL_NUMBER)) or (p[] == '.' and i > 0 and row[].hl[i - 1] == HL_NUMBER) {
            row[].hl[i] = HL_NUMBER
            p++
            i++
            prev_sep = false
            continue
        }

        # Handle keywords and lib calls
        if prev_sep {
            j: i32;
            loop j = 0 while keywords[j] .. j++ {
                klen: i32 = strlen(keywords[j])
                kw2: i32 = keywords[j][klen - 1] == '|'
                if kw2 {
                    klen--
                }

                if not memcmp(p, keywords[j], klen) and is_separator((p + klen)[]) {
                    # Keyword
                    memset(row[].hl + i, ? kw2 then HL_KEYWORD2 else HL_KEYWORD1, klen)
                    p += klen
                    i += klen
                    break
                }
            }
            if keywords[j] ~= nil {
                prev_sep = false
                continue # We had a keyword match
            }
        }

        # Not special chars
        prev_sep = is_separator(p[])
        p++
        i++
    }

    # Propagate syntax change to the next row if the open commen
    # state changed. This may recursively affect all the following rows
    # in the file.
    oc: bool = editorRowHasOpenComment(row)
    if row[].hl_oc ~= oc and row[].idx + 1 < E.numrows {
        editorUpdateSyntax(@E.row[row[].idx + 1])
    }
    row[].hl_oc = oc
}

# Maps syntax highlight token types to terminal colors.
fn editorSyntaxToColor(hl: i32) i32 {
    match hl {
        -> HL_COMMENT {
            -> HL_MLCOMMENT {
                return 36
            }
        } # cyan
        -> HL_KEYWORD1 {
            return 33
        } # yellow
        -> HL_KEYWORD2 {
            return 32
        } # green
        -> HL_STRING {
            return 35
        } # magenta
        -> HL_NUMBER {
            return 31
        } # red
        -> HL_MATCH {
            return 34
        } # blue
        otherwise {
            return 37
        } # white
    }
}

# Select the syntax highlight scheme depending on the filename,
# setting it in the global state E.syntax.
fn editorSelectSyntaxHighlight(filename: string) none {
    loop j: u32 = 0 while j < HLDB_ENTRIES .. j++ {
        s: *struc editorSyntax = HLDB + j
        i: u32 = 0
        loop while s[].filematch[i] {
            p: string;
            patlen: i32 = strlen(s[].filematch[i])
            if (p = strstr(filename, s[].filematch[i])) ~= nil {
                if s[].filematch[i][0] ~= '.' or p[patlen] == nil {
                    E.syntax = s
                    return none
                }
            }
            i++
        }
    }
}

# ======================= Editor rows implementation =======================

# Update the rendered version and the syntax highlight of a row.
m4_define(MAX_U32, 4294967295u)m4_dnl
fn editorUpdateRow(row: *struc erow) none {
    tabs: u32 = 0
    nonprint: u32 = 0
    j: i32;
    idx: i32;

    # Create a version of the row we can directly print on the screen,
    # respecting tabs, substituting non printable characters with '?'.
    free(row[].render)
    loop j = 0 while j < row[].size .. j++ {
        if row[].chars[j] == TAB {
            tabs++
        }
    }

    allocsize: u64 = cast<u64>(row[].size) + tabs * 8 + nonprint * 9 + 1
    if allocsize > MAX_U32 {
        print("Some line of the edited file is too long for kilo\n")
        exit(1)
    }

    row[].render = malloc(row[].size + tabs * 8 + nonprint * 9 + 1)
    idx = 0
    loop j = 0 while j < row[].size .. j++ {
        if row[].chars[j] == TAB {
            row[].render[idx++] = ' '
            loop while (idx + 1) % 8 ~= 0 {
                row[].render[idx++] = ' '
            }
        }
        else {
            row[].render[idx++] = row[].chars[j]
        }
    }
    row[].rsize = idx
    row[].render[idx] = nil

    # Update the syntax highlighting attributes of the row.
    editorUpdateSyntax(row)
}

# Insert a row at the specified position, shifting the other rows on the bottom
# if required.
fn editorInsertRow(at: i32, s: string, len: u64) none {
    if at > E.numrows {
        return none
    }
    E.row = realloc(E.row, sizeof<struc erow> * (E.numrows + 1))
    if at ~= E.numrows {
        memmove(E.row + at + 1, E.row + at, sizeof(E.row[0]) * (E.numrows - at))
        loop j: i32 = at + 1 while j <= E.numrows .. j++ {
            E.row[j].idx++
        }
    }
    E.row[at].size = len
    E.row[at].chars = malloc(len + 1)
    memcpy(E.row[at].chars, s, len + 1)
    E.row[at].hl = nil
    E.row[at].hl_oc = false
    E.row[at].render = nil
    E.row[at].rsize = 0
    E.row[at].idx = at
    editorUpdateRow(E.row + at)
    E.numrows++
    E.dirty++
}

# Free row's heap allocated stuff.
fn editorFreeRow(row: *struc erow) none {
    free(row[].render)
    free(row[].chars)
    free(row[].hl)
}

# Remove the row at the specified position, shifting the remainign on the
# top.
fn editorDelRow(at: i32) none {
    row: *struc erow;

    if at >= E.numrows {
        return none
    }
    row = E.row + at
    editorFreeRow(row)
    memmove(E.row + at, E.row + at + 1, sizeof(E.row[0]) * (E.numrows - at - 1))
    loop j: i32 = at while j < E.numrows - 1 .. j++ {
        E.row[j].idx++
    }
    E.numrows--
    E.dirty++
}

# Turn the editor rows into a single heap-allocated string.
# Returns the pointer to the heap-allocated string and populate the
# integer pointed by 'buflen' with the size of the string, escluding
# the final nulterm.
fn editorRowsToString(buflen: *i32) string {
    buf: string = nil
    p: string;
    totlen: i32 = 0
    j: i32;

    # Compute count of bytes
    loop j = 0 while j < E.numrows .. j++ {
        totlen += E.row[j].size + 1
    } # +1 is for "\n" at end of every row
    buflen[] = totlen
    totlen++ # Also make space for nulterm

    p = (buf = malloc(totlen))
    loop j = 0 while j < E.numrows .. j++ {
        memcpy(p, E.row[j].chars, E.row[j].size)
        p += E.row[j].size
        p[] = '\n'
        p++
    }
    p[] = nil
    return buf
}

# Insert a character at the specified position in a row, moving the remaining
# chars on the right if needed.
fn editorRowInsertChar(row: *struc erow, at: i32, c: i32) none {
    if at > row[].size {
        # Pad the string with spaces if the insert location is outside the
        # current length by more than a single character.
        padlen: i32 = at - row[].size
        # In the next line +2 means: new char and null term.
        row[].chars = realloc(row[].chars, row[].size + padlen + 2)
        memset(row[].chars + row[].size, ' ', padlen)
        row[].chars[row[].size + padlen + 1] = nil
        row[].size += padlen + 1
    }
    else {
        # If we are in the middle of the string just make space for 1 new
        # char plus the (already existing) null term.
        row[].chars = realloc(row[].chars, row[].size + 2)
        memmove(row[].chars + at + 1, row[].chars + at, row[].size - at + 1)
        row[].size++
    }
    row[].chars[at] = c
    editorUpdateRow(row)
    E.dirty++
}

# Append the string 's' at the end of a row
fn editorRowAppendString(row: *struc erow, s: string, len: u64) none {
    row[].chars = realloc(row[].chars, row[].size + len + 1)
    memcpy(row[].chars + row[].size, s, len)
    row[].size += len
    row[].chars[row[].size] = nil
    editorUpdateRow(row)
    E.dirty++
}

# Delete the character at offset 'at' from the specified row.
fn editorRowDelChar(row: *struc erow, at: i32) none {
    if row[].size <= at {
        return none
    }
    memmove(row[].chars + at, row[].chars + at + 1, row[].size - at)
    editorUpdateRow(row)
    row[].size--
    E.dirty++
}

# Insert the specified char at the current prompt position.
fn editorInsertChar(c: i32) none {
    filerow: i32 = E.rowoff + E.cy
    filecol: i32 = E.coloff + E.cx
    row: *struc erow = ? (filerow >= E.numrows) then nil else @E.row[filerow]

    # If the row where the cursor is currently located does not exist in our
    # logical representaion of the file, add enough empty rows as needed.
    if not row {
        loop while E.numrows <= filerow {
            editorInsertRow(E.numrows, "", 0)
        }
    }
    row = @E.row[filerow]
    editorRowInsertChar(row, filecol, c)
    if E.cx == E.screencols - 1 {
        E.coloff++
    }
    else {
        E.cx++
    }
    E.dirty++
}

# Inserting a newline is slightly complex as we have to handle inserting a
# newline in the middle of a line, splitting the line as needed.
fn editorInsertNewline(none) none {
    filerow: i32 = E.rowoff + E.cy
    filecol: i32 = E.coloff + E.cx
    row: *struc erow = ? (filerow >= E.numrows) then nil else @E.row[filerow]

    if not row {
        if filerow == E.numrows {
            editorInsertRow(filerow, "", 0)
            jump fixcursor
        }
        return none
    }
    # If the cursor is over the current line size, we want to conceptually
    # think it's just over the last character.
    if filecol >= row[].size {
        filecol = row[].size
    }
    if filecol == 0 {
        editorInsertRow(filerow, "", 0)
    }
    else {
        # We are in the middle of a line. Split it between two rows.
        editorInsertRow(filerow + 1, row[].chars + filecol, row[].size - filecol)
        row = @E.row[filerow]
        row[].chars[filecol] = nil
        row[].size = filecol
        editorUpdateRow(row)
    }
    label fixcursor
    if E.cy == E.screenrows - 1 {
        E.rowoff++
    }
    else {
        E.cy++
    }
    E.cx = 0
    E.coloff = 0
}

# Delete the char at the current prompt position.
fn editorDelChar(none) none {
    filerow: i32 = E.rowoff + E.cy
    filecol: i32 = E.coloff + E.cx
    row: *struc erow = ? (filerow >= E.numrows) then nil else @E.row[filerow]

    if not row or (filecol == 0 and filerow == 0) {
        return none
    }
    if filecol == 0 {
        # Handle the case of column 0, we need to move the current line
        # on the right of the previous one.
        filecol = E.row[filerow - 1].size
        editorRowAppendString(@E.row[filerow - 1], row[].chars, row[].size)
        editorDelRow(filerow)
        row = nil
        if E.cy == 0 {
            E.rowoff--
        }
        else {
            E.cy--
        }
        E.cx = filecol
        if E.cx >= E.screencols {
            shift: i32 = (E.screencols - E.cx) + 1
            E.cx -= shift
            E.coloff += shift
        }
    }
    else {
        editorRowDelChar(row, filecol - 1)
        if E.cx == 0 and E.coloff {
            E.coloff--
        }
        else {
            E.cx--
        }
    }
    if row {
        editorUpdateRow(row)
    }
    E.dirty++
}

# Load the specified program in the editor memory and returns 0 on success
# or 1 on error.
fn editorOpen(filename: string) i32 {
    fp: *struc FILE;

    E.dirty = false
    free(E.filename)
    fnlen: u64 = strlen(filename) + 1
    E.filename = malloc(fnlen)
    memcpy(E.filename, filename, fnlen)

    fp = fopen(filename, "r")
    if not fp {
        if get_errno() ~= ENOENT {
            perror("Opening file")
            exit(1)
        }
        return 1
    }

    line: string = nil
    linecap: u64 = 0
    linelen: i64;
    loop while (linelen = getline(@line, @linecap, fp)) ~= -1 {
        if linelen and (line[linelen - 1] == '\n' or line[linelen - 1] == '\r') {
            line[--linelen] = nil
        }
        editorInsertRow(E.numrows, line, linelen)
    }
    free(line)
    fclose(fp)
    E.dirty = false
    return 0
}

# Save the current file on disk. Return 0 on success, 1 on error.
fn editorSave(none) i32 {
    len: i32;
    buf: string = editorRowsToString(@len)
    fd: i32 = open(E.filename, O_RDWR | O_CREAT, COPYMODE)
    if fd == -1 {
        jump writeerr
    }

    # Use truncate + a single write(2) call in order to make saving
    # a bit safer, under the limits of what we can do in a small editor.
    if ftruncate(fd, len) == -1 {
        jump writeerr
    }
    if write(fd, buf, len) ~= len {
        jump writeerr
    }

    close(fd)
    free(buf)
    E.dirty = false
    sd: [20]char;
    editorSetStatusMessage(fmt2(ltostr(sd, len), " bytes written on disk"))
    return 0

    label writeerr
    free(buf)
    if fd ~= -1 {
        close(fd)
    }
    editorSetStatusMessage(fmt2("Can't save! I/O error: ", strerror(get_errno())))
    return 1
}

# ============================= Terminal update ============================

# We define a very simple "append buffer" structure, that is an heap
# allocated string where we can append to. This is useful in order to
# write all the escape sequences in a buffer and flush them to the standard
# output in a single call, to avoid flickering effects.
type struc abuf(
    b: string,
    len: i32
)

m4_define(`ABUF_INIT', `$(nil, 0)')m4_dnl

fn abAppend(ab: *struc abuf, s: string, len: i32) none {
    new: string = realloc(ab[].b, ab[].len + len)

    if new == nil {
        return none
    }
    memcpy(new + ab[].len, s, len)
    ab[].b = new
    ab[].len += len
}

fn abFree(ab: *struc abuf) none {
    free(ab[].b)
}

# This function writes the whole screen using VT100 escape characters
# starting from the logical state of the editor in the global state 'E'.
fn editorRefreshScreen(none) none {
    y: i32;
    r: *struc erow;
    buf: [32]char;
    sd: [2][20]char;
    ab: struc abuf = ABUF_INIT

    abAppend(@ab, x1b_hide_cur, 6) # Hide cursor.
    abAppend(@ab, x1b_move_cur_home, 3) # Go home.
    loop y = 0 while y < E.screenrows .. y++ {
        filerow: i32 = E.rowoff + y

        if filerow >= E.numrows {
            if E.numrows == 0 and y == E.screenrows / 3 {
                welcome: [80]char;
                welcomelen: i32 = snprint(welcome, sizeof(welcome), fmt3("Kilo editor -- version ", KILO_VERSION, x1b_erase_cur_crlf))
                padding: i32 = (E.screencols - welcomelen) / 2
                if padding {
                    abAppend(@ab, "~", 1)
                    padding--
                }
                loop while padding-- {
                    abAppend(@ab, " ", 1)
                }
                abAppend(@ab, welcome, welcomelen)
            }
            else {
                abAppend(@ab, x1b_put_blank_line, 7)
            }
            continue
        }

        r = @E.row[filerow]

        len: i32 = r[].rsize - E.coloff
        current_color: i32 = -1
        if len > 0 {
            if len > E.screencols {
                len = E.screencols
            }
            c: string = r[].render + E.coloff
            hl: *u8 = r[].hl + E.coloff
            j: i32;
            loop j = 0 while j < len .. j++ {
                if hl[j] == HL_NONPRINT {
                    sym: char;
                    abAppend(@ab, x1b_set_inv_mode, 4)
                    if c[j] <= 26 {
                        sym = '@' + c[j]
                    }
                    else {
                        sym = '?'
                    }
                    abAppend(@ab, @sym, 1)
                    abAppend(@ab, x1b_reset_modes, 4)
                }
                elif hl[j] == HL_NORMAL {
                    if current_color ~= -1 {
                        abAppend(@ab, x1b_set_def_fgcol, 5)
                        current_color = -1
                    }
                    abAppend(@ab, c + j, 1)
                }
                else {
                    color: i32 = editorSyntaxToColor(hl[j])
                    if color ~= current_color {
                        buf: [16]char;
                        clen: i32 = snprint(buf, sizeof(buf), fmt3(x1b_prefix, ltostr(sd[0], color), "m"))
                        current_color = color
                        abAppend(@ab, buf, clen)
                    }
                    abAppend(@ab, c + j, 1)
                }
            }
        }
        abAppend(@ab, x1b_set_def_fgcol, 5)
        abAppend(@ab, x1b_erase_cur_crlf, 6)
    }

    # Create a two rows status. First row:
    abAppend(@ab, x1b_erase_cur, 4)
    abAppend(@ab, x1b_set_inv_mode, 4)
    status: [80]char;
    rstatus: [80]char;
    len: i32 = snprint(status, sizeof(status), fmt5(E.filename, " - ", ltostr(sd[0], E.numrows), " lines ", ? E.dirty then "(modified)" else ""))
    rlen: i32 = snprint(rstatus, sizeof(rstatus), fmt3(ltostr(sd[1], E.rowoff + E.cy + 1), "/", sd[0]))
    if len > E.screencols {
        len = E.screencols
    }
    abAppend(@ab, status, len)
    loop while len < E.screencols {
        if E.screencols - len == rlen {
            abAppend(@ab, rstatus, rlen)
            break
        }
        else {
            abAppend(@ab, " ", 1)
            len++
        }
    }
    abAppend(@ab, x1b_reset_modes_clrf, 6)

    # Second row depends on E.statusmsg and the status message update time.
    abAppend(@ab, x1b_erase_cur, 4)
    msglen: i32 = strlen(E.statusmsg)
    if msglen and time(nil) - E.statusmsg_time < 5 {
        abAppend(@ab, E.statusmsg, ? msglen <= E.screencols then msglen else E.screencols)
    }

    # Put cursor at its current position. Note that the horizontal position
    # at which the cursor is displayed may be different compared to 'E.cx'
    # because of TABs.
    j: i32;
    cx: i32 = 1
    filerow: i32 = E.rowoff + E.cy
    row: *struc erow = ? (filerow >= E.numrows) then nil else @E.row[filerow]
    if row {
        loop j = E.coloff while j < (E.cx + E.coloff) .. j++ {
            if j < row[].size and row[].chars[j] == TAB {
                cx += 7 - ((cx) % 8)
            }
            cx++
        }
    }
    snprint(buf, sizeof(buf), fmt5(x1b_prefix, ltostr(sd[0], E.cy + 1), ";", ltostr(sd[1], cx), "H"))
    abAppend(@ab, buf, strlen(buf))
    abAppend(@ab, x1b_show_cur, 6) # Show cursor.
    write(STDOUT_FILENO, ab.b, ab.len)
    abFree(@ab)
}

# Set an editor status message for the second line of the status, at the
# end of the screen.
fn editorSetStatusMessage(format: string) none {
    snprint(E.statusmsg, sizeof(E.statusmsg), format)
    E.statusmsg_time = time(nil)
}

# =============================== Find mode ================================

m4_define(KILO_QUERY_LEN, 256)m4_dnl

fn editorFind(fd: i32) none {
    query: [m4_incr(KILO_QUERY_LEN)]char = $(0)
    qlen: i32 = 0
    last_match: i32 = -1 # Last line where a match was found. -1 for none.
    find_next: i32 = 0 # if 1 search next, if -1 search prev.
    saved_hl_line: i32 = -1 # No saved HL
    saved_hl: string = nil

m4_define(`FIND_RESTORE_HL', `
    if saved_hl {
        memcpy(E.row[saved_hl_line].hl, saved_hl, E.row[saved_hl_line].rsize)
        free(saved_hl)
        saved_hl = nil
    }
')m4_dnl

    # Save the cursor position in order to restore it later.
    saved_cx: i32 = E.cx
    saved_cy: i32 = E.cy
    saved_coloff: i32 = E.coloff
    saved_rowoff: i32 = E.rowoff

    loop {
        editorSetStatusMessage(fmt3("Search: ", query, " (Use Esc/Arrows/Enter)"))
        editorRefreshScreen()

        c: i32 = editorReadKey(fd)
        if c == DEL_KEY or c == CTRL_H or c == BACKSPACE {
            if qlen ~= 0 {
                query[--qlen] = nil
            }
            last_match = -1
        }
        elif c == ESC or c == ENTER {
            if c == ESC {
                E.cx = saved_cx
                E.cy = saved_cy
                E.coloff = saved_coloff
                E.rowoff = saved_rowoff
            }
            FIND_RESTORE_HL
            editorSetStatusMessage("")
            return none
        }
        elif c == ARROW_RIGHT or c == ARROW_DOWN {
            find_next = 1
        }
        elif c == ARROW_LEFT or c == ARROW_UP {
            find_next = -1
        }
        elif isprint(c) {
            if qlen < KILO_QUERY_LEN {
                query[qlen++] = c
                query[qlen] = nil
                last_match = -1
            }
        }

        # Search occurrence.
        if last_match == -1 {
            find_next = 1
        }
        if find_next {
            next_match: string = nil
            match_offset: i32 = 0
            i: i32;
            current: i32 = last_match

            loop i = 0 while i < E.numrows .. i++ {
                current += find_next
                if current == -1 {
                    current = E.numrows - 1
                }
                elif current == E.numrows {
                    current = 0
                }
                next_match = strstr(E.row[current].render, query)
                if next_match {
                    match_offset = next_match - E.row[current].render
                    break
                }
            }
            find_next = 0

            # Highlight
            FIND_RESTORE_HL

            if next_match {
                row: *struc erow = @E.row[current]
                last_match = current
                if row[].hl {
                    saved_hl_line = current
                    saved_hl = malloc(row[].rsize)
                    memcpy(saved_hl, row[].hl, row[].rsize)
                    memset(row[].hl + match_offset, HL_MATCH, qlen)
                }
                E.cy = 0
                E.cx = match_offset
                E.rowoff = current
                E.coloff = 0
                # Scroll horizontally as needed.
                if E.cx > E.screencols {
                    diff: i32 = E.cx - E.screencols
                    E.cx -= diff
                    E.coloff += diff
                }
            }
        }
    }
}

# ========================= Editor events handling  ========================

# Handle cursor position change because arrow keys were pressed.
fn editorMoveCursor(key: i32) none {
    filerow: i32 = E.rowoff + E.cy
    filecol: i32 = E.coloff + E.cx
    rowlen: i32;
    row: *struc erow = ? (filerow >= E.numrows) then nil else @E.row[filerow]

    match key {
        -> ARROW_LEFT {
            if E.cx == 0 {
                if E.coloff {
                    E.coloff--
                }
                else {
                    if filerow > 0 {
                        E.cy--
                        E.cx = E.row[filerow - 1].size
                        if E.cx > E.screencols - 1 {
                            E.coloff = E.cx - E.screencols + 1
                            E.cx = E.screencols - 1
                        }
                    }
                }
            }
            else {
                E.cx -= 1
            }
        }
        break
        -> ARROW_RIGHT {
            if row and filecol < row[].size {
                if E.cx == E.screencols - 1 {
                    E.coloff++
                }
                else {
                    E.cx += 1
                }
            }
            elif row and filecol == row[].size {
                E.cx = 0
                E.coloff = 0
                if E.cy == E.screenrows - 1 {
                    E.rowoff++
                }
                else {
                    E.cy += 1
                }
            }
        }
        break
        -> ARROW_UP {
            if E.cy == 0 {
                if E.rowoff {
                    E.rowoff--
                }
            }
            else {
                E.cy -= 1
            }
        }
        break
        -> ARROW_DOWN {
            if filerow < E.numrows {
                if E.cy == E.screenrows - 1 {
                    E.rowoff++
                }
                else {
                    E.cy += 1
                }
            }
        }
        break
    }
    # Fix cx if the current line has not enough chars.
    filerow = E.rowoff + E.cy
    filecol = E.coloff + E.cx
    row = ? (filerow >= E.numrows) then nil else @E.row[filerow]
    rowlen = ? row then row[].size else 0
    if filecol > rowlen {
        E.cx -= filecol - rowlen
        if E.cx < 0 {
            E.coloff += E.cx
            E.cx = 0
        }
    }
}

# Process events arriving from the standard input, which is, the user
# is typing stuff on the terminal.
m4_define(KILO_QUIT_TIMES, 3)m4_dnl
fn editorProcessKeypress(fd: i32) none {
    # When the file is modified, requires Ctrl-q to be pressed N times
    # before actually quitting.
    data quit_times: i32 = KILO_QUIT_TIMES

    c: i32 = editorReadKey(fd)
    match c {
        -> ENTER { # Enter
            editorInsertNewline()
        }
        break
        -> CTRL_C { # Ctrl-c
            # We ignore ctrl-c, it can't be so simple to lose the changes
            # to the edited file.
            break
        }
        -> CTRL_Q { # Ctrl-q
            # Quit if the file was already saved.
            if E.dirty and quit_times {
                sd: [20]char;
                editorSetStatusMessage(fmt3("WARNING!!! File has unsaved changes. Press Ctrl-Q ", ltostr(sd, quit_times), " more times to quit."))
                quit_times--
                return none
            }
        }
        exit(0)
        break
        -> CTRL_S { # Ctrl-s
            editorSave()
        }
        break
        -> CTRL_F {
            editorFind(fd)
        }
        break
        -> BACKSPACE { # Backspace
            -> CTRL_H { # Ctrl-h
                -> DEL_KEY {
                    editorDelChar()
                }
            }
        }
        break
        -> PAGE_UP {
            -> PAGE_DOWN {
                if c == PAGE_UP and E.cy ~= 0 {
                    E.cy = 0
                }
                elif c == PAGE_DOWN and E.cy ~= E.screenrows - 1 {
                    E.cy = E.screenrows - 1
                }
            }
        }
        {
            times: i32 = E.screenrows
            loop while times-- {
                editorMoveCursor(? c == PAGE_UP then ARROW_UP else ARROW_DOWN)
            }
        }
        break

        -> ARROW_UP {
            -> ARROW_DOWN {
                -> ARROW_LEFT {
                    -> ARROW_RIGHT {
                        editorMoveCursor(c)
                    }
                }
            }
        }
        break
        -> CTRL_L { # ctrl+l, clear screen
            # Just refresht the line as side effect.
            break
        }
        -> ESC {
            # Nothing to do for ESC in this mode.
            break
        }
        otherwise {
            editorInsertChar(c)
        }
        break
    }

    quit_times = KILO_QUIT_TIMES # Reset it to the original value.
}

fn editorFileWasModified(none) bool {
    return E.dirty
}

fn updateWindowSize(none) none {
    if getWindowSize(STDIN_FILENO, STDOUT_FILENO, @E.screenrows, @E.screencols) == -1 {
        perror("Unable to query the screen for size (columns / rows)")
        exit(1)
    }
    E.screenrows -= 2 # Get room for status bar.
}

fn handleSigWinCh(none) none {
    updateWindowSize()
    if E.cy > E.screenrows {
        E.cy = E.screenrows - 1
    }
    if E.cx > E.screencols {
        E.cx = E.screencols - 1
    }
    editorRefreshScreen()
}

pub fn signal_func(sig: i32) none {
    if sig == SIGWINCH {
        handleSigWinCh()
    }
}

fn initEditor(none) none {
    E.cx = 0
    E.cy = 0
    E.rowoff = 0
    E.coloff = 0
    E.numrows = 0
    E.row = nil
    E.dirty = false
    E.filename = nil
    E.syntax = nil
    updateWindowSize()
    signal_f(SIGWINCH)
}

pub fn main(argc: i32, argv: *string) i32 {
    if argc ~= 2 {
        fprint(get_stderr(), "Usage: kilo <filename>\n")
        exit(1)
    }

    initEditor()
    editorSelectSyntaxHighlight(argv[1])
    editorOpen(argv[1])
    enableRawMode(STDIN_FILENO)
    editorSetStatusMessage("HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find")
    loop {
        editorRefreshScreen()
        editorProcessKeypress(STDIN_FILENO)
    }
    return 0
}

# Copyright 2026 Romain Ducrocq
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# 
# -----------------------------------------------------------------------
# 
# Copyright (C) 2016 Salvatore Sanfilippo <antirez at gmail dot com>
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
#  *  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
# 
#  *  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
