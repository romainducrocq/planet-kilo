// This is a port of the (very simple) Kilo text editor by antirez, to planet
// https://github.com/antirez/kilo - see copyright at the bottom of this file

// Kilo -- A very simple editor in less than 1-kilo lines of code (as counted
//         by "cloc"). Does not depend on libcurses, directly emits VT100
//         escapes on the terminal.

char* KILO_VERSION = "0.0.1-planet"; // DEFINE

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wbuiltin-declaration-mismatch"
// ctype.h
extern int isdigit(int c);
extern int isprint(int c);
extern int isspace(int c);

// errno.h
extern int get_errno(void);
extern void set_errno(int value);

// stdio.h
int NULL = 0; // DEFINE
struct FILE;
extern struct FILE* get_stderr(void);
extern struct FILE* fopen(char* filename, char* mode);
extern int fclose(struct FILE* stream);
extern void perror(char* s);
extern int print(char* format);
extern int fprint(struct FILE* stream, char* format);
extern int snprint(char* s, unsigned long n, char* format);
extern int sscan(char* s, void* valptr, char* format);
extern char* fmt2(char* s1, char* s2);
extern char* fmt3(char* s1, char* s2, char* s3);
extern char* fmt5(char* s1, char* s2, char* s3, char* s4, char* s5);
extern char* ltostr(char* s, long value);

// stdlib.h
void atexit_func(void);
extern int atexit_f(void);
extern void exit(int status);
extern void* realloc(void* ptr, unsigned long size);
extern void free(void* ptr);
extern void* malloc(unsigned long size);

// string.h
extern void* memcpy(void* s1, void* s2, unsigned long n);
extern void* memmove(void* s1, void* s2, unsigned long n);
extern int memcmp(void* s1, void* s2, unsigned long n);
extern char* strchr(char* s, int c);
extern char* strstr(char* s1, char* s2);
extern void* memset(void* s, int c, unsigned long n);
extern char* strerror(int errnum);
extern unsigned long strlen(char* s);

// time.h
extern unsigned long time(unsigned long* timer);

// signal.h
void signal_func(int sig);
extern int signal_f(int sig);
#pragma GCC diagnostic pop

// Syntax highlight types
int HL_NORMAL = 0;    // DEFINE
int HL_NONPRINT = 1;  // DEFINE
int HL_COMMENT = 2;   // DEFINE // Single line comment.
int HL_MLCOMMENT = 3; // DEFINE // Multi-line comment.
int HL_KEYWORD1 = 4;  // DEFINE
int HL_KEYWORD2 = 5;  // DEFINE
int HL_STRING = 6;    // DEFINE
int HL_NUMBER = 7;    // DEFINE
int HL_MATCH = 8;     // DEFINE // Search match.

int HL_HIGHLIGHT_STRINGS = 1; // DEFINE // (1 << 0)
int HL_HIGHLIGHT_NUMBERS = 2; // DEFINE // (1 << 1)

struct editorSyntax {
    char* filematch[6];
    char* keywords[82];
    char singleline_comment_start[2];
    char multiline_comment_start[3];
    char multiline_comment_end[3];
    int flags;
};

// This structure represents a single line of the file we are editing.
struct erow {
    int idx;           // Row index in the file, zero-based.
    int size;          // Size of the row, excluding the null term.
    int rsize;         // Size of the rendered row.
    char* chars;       // Row content.
    char* render;      // Row content "rendered" for screen (for TABs).
    unsigned char* hl; // Syntax highlight type for each character in render.
    int hl_oc;         // Row had open comment at end in last syntax highlight
                       // check.
};

struct editorConfig {
    int cx; // Cursor x and y position in characters
    int cy;
    int rowoff;       // Offset of row displayed.
    int coloff;       // Offset of column displayed.
    int screenrows;   // Number of rows that we can show
    int screencols;   // Number of cols that we can show
    int numrows;      // Number of rows
    int rawmode;      // Is terminal raw mode enabled?
    struct erow* row; // Rows
    int dirty;        // File modified but not saved.
    char* filename;   // Currently open filename
    char statusmsg[80];
    unsigned long statusmsg_time;
    struct editorSyntax* syntax; // Current syntax highlight, or NULL.
};

static struct editorConfig E;

// KEY_ACTION
int KEY_NULL = 0;    // DEFINE // NULL
int CTRL_C = 3;      // DEFINE // Ctrl-c
int CTRL_D = 4;      // DEFINE // Ctrl-d
int CTRL_F = 6;      // DEFINE // Ctrl-f
int CTRL_H = 8;      // DEFINE // Ctrl-h
int TAB = 9;         // DEFINE // Tab
int CTRL_L = 12;     // DEFINE // Ctrl+l
int ENTER = 13;      // DEFINE // Enter
int CTRL_Q = 17;     // DEFINE // Ctrl-q
int CTRL_S = 19;     // DEFINE // Ctrl-s
int CTRL_U = 21;     // DEFINE // Ctrl-u
int ESC = 27;        // DEFINE // Escape
int BACKSPACE = 127; // DEFINE // Backspace
// The following are just soft codes, not really reported by the
// terminal directly.
int ARROW_LEFT = 1000;  // DEFINE
int ARROW_RIGHT = 1001; // DEFINE
int ARROW_UP = 1002;    // DEFINE
int ARROW_DOWN = 1003;  // DEFINE
int DEL_KEY = 1004;     // DEFINE
int HOME_KEY = 1005;    // DEFINE
int END_KEY = 1006;     // DEFINE
int PAGE_UP = 1007;     // DEFINE
int PAGE_DOWN = 1008;   // DEFINE

void editorSetStatusMessage(char* format);

// =========================== POSIX header bindings ========================

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wbuiltin-declaration-mismatch"
// termios.h
struct termios {
    unsigned int c_iflag;   // input mode flags
    unsigned int c_oflag;   // output mode flags
    unsigned int c_cflag;   // control mode flags
    unsigned int c_lflag;   // local mode flags
    unsigned char c_line;   // line discipline
    unsigned char c_cc[32]; // control characters
    unsigned int c_ispeed;  // input speed
    unsigned int c_ospeed;  // output speed
};
extern int tcsetattr(int fd, int optional_actions, struct termios* termios_p);
extern int tcgetattr(int fd, struct termios* termios_p);
int TCSAFLUSH = 2;  // DEFINE
int BRKINT = 2;     // DEFINE // 0000002 Signal interrupt on break.
int INPCK = 16;     // DEFINE // 0000020 Enable input parity check.
int ISTRIP = 32;    // DEFINE // 0000040 Strip 8th bit off characters.
int ICRNL = 256;    // DEFINE // 0000400 Map CR to NL on input.
int IXON = 1024;    // DEFINE // 0002000 Enable start/stop output control.
int OPOST = 1;      // DEFINE // 0000001 Post-process output.
int CS8 = 48;       // DEFINE // 0000060
int ECHO = 8;       // DEFINE // 0000010 Enable echo.
int ICANON = 2;     // DEFINE // 0000002 Canonical input (erase and kill processing).
int IEXTEN = 32768; // DEFINE // 0100000 Enable implementation-defined input processing.
int ISIG = 1;       // DEFINE // 0000001 Enable signals.
int VTIME = 5;      // DEFINE
int VMIN = 6;       // DEFINE

// errno.h
int ENOENT = 2;  // DEFINE // No such file or directory
int ENOTTY = 25; // DEFINE // Not a typewriter

// stdio.h
// _POSIX_C_SOURCE 200809L
extern long getline(char** lineptr, unsigned long* n, struct FILE* stream);

// sys/ioctl.h
struct winsize {
    unsigned char ws_row[2];
    unsigned char ws_col[2];
    unsigned char ws_xpixel[2];
    unsigned char ws_ypixel[2];
};
extern int ioctl(int fd, unsigned long int request, struct winsize* ws);
int TIOCGWINSZ = 21523; // DEFINE // 0x5413

// unistd.h
extern int isatty(int fd);
extern long read(int fd, void* buf, unsigned long nbytes);
extern long write(int fd, void* buf, unsigned long n);
extern int ftruncate(int fd, long length);
extern int close(int fd);
int STDIN_FILENO = 0;  // DEFINE // Standard input.
int STDOUT_FILENO = 1; // DEFINE // Standard output.

// fcntl.h
extern int open(char* path, int oflag, unsigned int mode);
int O_RDWR = 2;     // DEFINE 02
int O_CREAT = 64;   // DEFINE 0100
int COPYMODE = 420; // DEFINE 0644

// signal.h
// Nonstandard signals found in all modern POSIX systems
// (including both BSD and Linux).
int SIGWINCH = 28; // Window size change (4.3 BSD, Sun).
#pragma GCC diagnostic pop

// =========================== ANSI escape sequences ========================
// https://gist.github.com/ConnerWill/d4b6c776b509add763e17f9f113fd25b

char x1b_prefix[3] = {27, '[', 0}; // DEFINE ESC NULL

char x1b_move_cur_home[4] = {27, '[', 'H', 0};                        // DEFINE ESC NULL
char x1b_get_cur_pos[5] = {27, '[', '6', 'n', 0};                     // DEFINE ESC NULL
char x1b_show_cur[7] = {27, '[', '?', '2', '5', 'h', 0};              // DEFINE ESC NULL
char x1b_hide_cur[7] = {27, '[', '?', '2', '5', 'l', 0};              // DEFINE ESC NULL
char x1b_erase_cur[5] = {27, '[', '0', 'K', 0};                       // DEFINE ESC NULL
char X1B_erase_cur_crlf[7] = {27, '[', '0', 'K', '\r', '\n', 0};      // DEFINE ESC NULL
char x1b_put_blank_line[8] = {'~', 27, '[', '0', 'K', '\r', '\n', 0}; // DEFINE ESC NULL

char x1b_set_inv_mode[5] = {27, '[', '7', 'm', 0};                 // DEFINE ESC NULL
char x1b_reset_modes[5] = {27, '[', '0', 'm', 0};                  // DEFINE ESC NULL
char x1b_reset_modes_clrf[7] = {27, '[', '0', 'm', '\r', '\n', 0}; // DEFINE ESC NULL

char x1b_set_def_fgcol[6] = {27, '[', '3', '9', 'm', 0};                                    // DEFINE ESC NULL
char x1b_get_ws_rowcol[13] = {27, '[', '9', '9', '9', 'C', 27, '[', '9', '9', '9', 'B', 0}; // DEFINE ESC NULL

// =========================== Syntax highlights DB =========================
//
// In order to add a new syntax, define two arrays with a list of file name
// matches and keywords. The file name matches are used in order to match
// a given syntax with a given file name: if a match pattern starts with a
// dot, it is matched as the last past of the filename, for example ".c".
// Otherwise the pattern is just searched inside the filenme, like "Makefile").
//
// The list of keywords to highlight is just a list of words, however if they
// a trailing '|' character is added at the end, they are highlighted in
// a different color, so that you can have two different sets of keywords.
//
// Finally add a stanza in the HLDB global variable with two two arrays
// of strings, and a set of flags in order to enable highlighting of
// comments and numbers.
//
// The characters for single and multi line comments must be exactly two
// and must be provided as well (see the C language example).
//
// There is no support to highlight patterns currently.

// C / C++
// Here we define an array of syntax highlights by extensions, keywords,
// comments delimiters and flags.
unsigned int HLDB_ENTRIES = 1;  // DEFINE
struct editorSyntax HLDB[1] = {{// C / C++
    // C_HL_extensions
    {".c", ".h", ".cpp", ".hpp", ".cc", 0}, // DEFINE NULL
    // C_HL_keywords
    {// C Keywords
        "auto", "break", "case", "continue", "default", "do", "else", "enum", "extern", "for", "goto", "if", "register",
        "return", "sizeof", "static", "struct", "switch", "typedef", "union", "volatile", "while", "NULL",

        // C++ Keywords
        "alignas", "alignof", "and", "and_eq", "asm", "bitand", "bitor", "class", "compl", "constexpr", "const_cast",
        "deltype", "delete", "dynamic_cast", "explicit", "export", "false", "friend", "inline", "mutable", "namespace",
        "new", "noexcept", "not", "not_eq", "nullptr", "operator", "or", "or_eq", "private", "protected", "public",
        "reinterpret_cast", "static_assert", "static_cast", "template", "this", "thread_local", "throw", "true", "try",
        "typeid", "typename", "virtual", "xor", "xor_eq",

        // C types
        "int|", "long|", "double|", "float|", "char|", "unsigned|", "signed|", "void|", "short|", "auto|", "const|",
        "bool|", 0},       // DEFINE NULL
    "//", "/*", "*/", 3}}; // DEFINE HL_HIGHLIGHT_STRINGS | HL_HIGHLIGHT_NUMBERS

// ======================= Low level terminal handling ======================

static struct termios orig_termios; // In order to restore at exit.

void disableRawMode(int fd) {
    // Don't even check the return value as it's too late.
    if (E.rawmode) {
        tcsetattr(fd, TCSAFLUSH, &orig_termios);
        E.rawmode = 0;
    }
}

// Called at exit to avoid remaining in raw mode.
void editorAtExit(void) { disableRawMode(STDIN_FILENO); }

void atexit_func(void) { editorAtExit(); }

// Raw mode: 1960 magic shit.
int enableRawMode(int fd) {
    struct termios raw;

    if (E.rawmode)
        return 0; // Already enabled.
    if (!isatty(STDIN_FILENO))
        goto fatal;
    atexit_f();
    if (tcgetattr(fd, &orig_termios) == -1)
        goto fatal;

    raw = orig_termios; // modify the original mode
    // input modes: no break, no CR to NL, no parity check, no strip char,
    // no start/stop output control.
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    // output modes - disable post processing
    raw.c_oflag &= ~(OPOST);
    // control modes - set 8 bit chars
    raw.c_cflag |= (CS8);
    // local modes - choing off, canonical off, no extended functions,
    // no signal chars (^Z,^C)
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    // control chars - set return condition: min number of bytes and timer.
    raw.c_cc[VMIN] = 0;  // Return each byte, or zero for timeout.
    raw.c_cc[VTIME] = 1; // 100 ms timeout (unit is tens of second).

    // put terminal in raw mode after flushing
    if (tcsetattr(fd, TCSAFLUSH, &raw) < 0)
        goto fatal;
    E.rawmode = 1;
    return 0;

fatal:
    set_errno(ENOTTY);
    return -1;
}

// Read a key from the terminal put in raw mode, trying to handle
// escape sequences.
int editorReadKey(int fd) {
    int nread;
    char c;
    char seq[3];
    while ((nread = read(fd, &c, 1)) == 0)
        ;
    if (nread == -1)
        exit(1);

    while (1) {
        switch (c) {
            case 27: // DEFINE ESC // escape sequence
                // If this is just an ESC, we'll timeout here.
                if (read(fd, seq, 1) == 0)
                    return ESC;
                if (read(fd, seq + 1, 1) == 0)
                    return ESC;

                // ESC [ sequences.
                if (seq[0] == '[') {
                    if (seq[1] >= '0' && seq[1] <= '9') {
                        // Extended escape, read additional byte.
                        if (read(fd, seq + 2, 1) == 0)
                            return ESC;
                        if (seq[2] == '~') {
                            switch (seq[1]) {
                                case '3':
                                    return DEL_KEY;
                                case '5':
                                    return PAGE_UP;
                                case '6':
                                    return PAGE_DOWN;
                            }
                        }
                    }
                    else {
                        switch (seq[1]) {
                            case 'A':
                                return ARROW_UP;
                            case 'B':
                                return ARROW_DOWN;
                            case 'C':
                                return ARROW_RIGHT;
                            case 'D':
                                return ARROW_LEFT;
                            case 'H':
                                return HOME_KEY;
                            case 'F':
                                return END_KEY;
                        }
                    }
                }

                // ESC O sequences.
                else if (seq[0] == 'O') {
                    switch (seq[1]) {
                        case 'H':
                            return HOME_KEY;
                        case 'F':
                            return END_KEY;
                    }
                }
                break;
            default:
                return c;
        }
    }
}

// Use the ESC [6n escape sequence to query the horizontal cursor position
// and return it. On error -1 is returned, on success the position of the
// cursor is stored at *rows and *cols and 0 is returned.
int getCursorPosition(int ifd, int ofd, int* rows, int* cols) {
    char buf[32];
    unsigned int i = 0;

    // Report cursor location
    if (write(ofd, x1b_get_cur_pos, 4) != 4)
        return -1;

    // Read the response: ESC [ rows ; cols R
    while (i < sizeof(buf) - 1) {
        if (read(ifd, buf + i, 1) != 1)
            break;
        if (buf[i] == 'R')
            break;
        i++;
    }
    buf[i] = NULL;

    // Parse it.
    if (buf[0] != ESC || buf[1] != '[')
        return -1;

    char* p = buf + 1;
    while (++p && *p) {
        if (*p == ';') {
            *p = 0;
            if (sscan(buf + 2, rows, "%d") != 1)
                return -1;
            if (sscan(p + 1, cols, "%d") != 1)
                return -1;
            break;
        }
    }
    return 0;
}

// Try to get the number of columns in the current terminal. If the ioctl()
// call fails the function will try to query the terminal itself.
// Returns 0 on success, -1 on error.
int getWindowSize(int ifd, int ofd, int* rows, int* cols) {
    struct winsize ws;

    if (ioctl(1, TIOCGWINSZ, &ws) == -1 || (ws.ws_col[0] | ws.ws_col[1]) == 0) {
        // ioctl() failed. Try to query the terminal itself.
        int orig_row;
        int orig_col;
        int retval;

        // Get the initial position so we can restore it later.
        retval = getCursorPosition(ifd, ofd, &orig_row, &orig_col);
        if (retval == -1)
            goto failed;

        // Go to right/bottom margin and get position.
        if (write(ofd, x1b_get_ws_rowcol, 12) != 12)
            goto failed;
        retval = getCursorPosition(ifd, ofd, rows, cols);
        if (retval == -1)
            goto failed;

        // Restore position.
        char seq[32];
        char sd1[20] = {0};
        char sd2[20] = {0};
        snprint(seq, 32, fmt5(x1b_prefix, ltostr(sd1, orig_row), ";", ltostr(sd2, orig_col), "H"));
        if (write(ofd, seq, strlen(seq)) == -1) {
            // Can't recover...
            ;
        }
        return 0;
    }
    else {
        *cols = ws.ws_col[0] + ((int)ws.ws_col[1] << 8);
        *rows = ws.ws_row[0] + ((int)ws.ws_row[1] << 8);
        return 0;
    }

failed:
    return -1;
}

// ====================== Syntax highlight color scheme  ====================

int is_separator(int c) { return c == NULL || isspace(c) || strchr(",.()+-/*=~%[];", c) != 0; } // DEFINE NULL

// Return true if the specified row last char is part of a multi line comment
// that starts at this row or at one before, and does not end at the end
// of the row but spawns to the next row.
int editorRowHasOpenComment(struct erow* row) {
    if (row->hl && row->rsize && row->hl[row->rsize - 1] == HL_MLCOMMENT
        && (row->rsize < 2 || (row->render[row->rsize - 2] != '*' || row->render[row->rsize - 1] != '/')))
        return 1;
    return 0;
}

// Set every byte of row->hl (that corresponds to every character in the line)
// to the right syntax highlight type (HL_* defines).
void editorUpdateSyntax(struct erow* row) {
    row->hl = realloc(row->hl, row->rsize);
    memset(row->hl, HL_NORMAL, row->rsize);

    if (E.syntax == 0) // DEFINE NULL
        return;        // No syntax, everything is HL_NORMAL.

    int i;
    int prev_sep;
    int in_string;
    int in_comment;
    char* p;
    char** keywords = E.syntax->keywords;
    char* scs = E.syntax->singleline_comment_start;
    char* mcs = E.syntax->multiline_comment_start;
    char* mce = E.syntax->multiline_comment_end;

    // Point to the first non-space char.
    p = row->render;
    i = 0; // Current char offset
    while (*p && isspace(*p)) {
        p++;
        i++;
    }
    prev_sep = 1;   // Tell the parser if 'i' points to start of word.
    in_string = 0;  // Are we inside "" or '' ?
    in_comment = 0; // Are we inside multi-line comment?

    // If the previous line has an open comment, this line starts
    // with an open comment state.
    if (row->idx > 0 && editorRowHasOpenComment(&E.row[row->idx - 1]))
        in_comment = 1;

    while (*p) {
        // Handle // comments.
        if (prev_sep && *p == scs[0] && *(p + 1) == scs[1]) {
            // From here to end is a comment
            memset(row->hl + i, HL_COMMENT, row->size - i);
            return;
        }

        // Handle multi line comments.
        if (in_comment) {
            row->hl[i] = HL_MLCOMMENT;
            if (*p == mce[0] && *(p + 1) == mce[1]) {
                row->hl[i + 1] = HL_MLCOMMENT;
                p += 2;
                i += 2;
                in_comment = 0;
                prev_sep = 1;
                continue;
            }
            else {
                prev_sep = 0;
                p++;
                i++;
                continue;
            }
        }
        else if (*p == mcs[0] && *(p + 1) == mcs[1]) {
            row->hl[i] = HL_MLCOMMENT;
            row->hl[i + 1] = HL_MLCOMMENT;
            p += 2;
            i += 2;
            in_comment = 1;
            prev_sep = 0;
            continue;
        }

        // Handle "" and ''
        if (in_string) {
            row->hl[i] = HL_STRING;
            if (*p == '\\') {
                row->hl[i + 1] = HL_STRING;
                p += 2;
                i += 2;
                prev_sep = 0;
                continue;
            }
            if (*p == in_string)
                in_string = 0;
            p++;
            i++;
            continue;
        }
        else {
            if (*p == '"' || *p == '\'') {
                in_string = *p;
                row->hl[i] = HL_STRING;
                p++;
                i++;
                prev_sep = 0;
                continue;
            }
        }

        // Handle non printable chars.
        if (!isprint(*p)) {
            row->hl[i] = HL_NONPRINT;
            p++;
            i++;
            prev_sep = 0;
            continue;
        }

        // Handle numbers
        if ((isdigit(*p) && (prev_sep || row->hl[i - 1] == HL_NUMBER))
            || (*p == '.' && i > 0 && row->hl[i - 1] == HL_NUMBER)) {
            row->hl[i] = HL_NUMBER;
            p++;
            i++;
            prev_sep = 0;
            continue;
        }

        // Handle keywords and lib calls
        if (prev_sep) {
            int j;
            for (j = 0; keywords[j]; j++) {
                int klen = strlen(keywords[j]);
                int kw2 = keywords[j][klen - 1] == '|';
                if (kw2)
                    klen--;

                if (!memcmp(p, keywords[j], klen) && is_separator(*(p + klen))) {
                    // Keyword
                    memset(row->hl + i, kw2 ? HL_KEYWORD2 : HL_KEYWORD1, klen);
                    p += klen;
                    i += klen;
                    break;
                }
            }
            if (keywords[j] != 0) { // DEFINE NULL
                prev_sep = 0;
                continue; // We had a keyword match
            }
        }

        // Not special chars
        prev_sep = is_separator(*p);
        p++;
        i++;
    }

    // Propagate syntax change to the next row if the open commen
    // state changed. This may recursively affect all the following rows
    // in the file.
    int oc = editorRowHasOpenComment(row);
    if (row->hl_oc != oc && row->idx + 1 < E.numrows)
        editorUpdateSyntax(&E.row[row->idx + 1]);
    row->hl_oc = oc;
}

// Maps syntax highlight token types to terminal colors.
int editorSyntaxToColor(int hl) {
    switch (hl) {
        case 2:        // DEFINE HL_COMMENT
        case 3:        // DEFINE HL_MLCOMMENT
            return 36; // cyan
        case 4:        // DEFINE HL_KEYWORD1
            return 33; // yellow
        case 5:        // DEFINE HL_KEYWORD2
            return 32; // green
        case 6:        // DEFINE HL_STRING
            return 35; // magenta
        case 7:        // DEFINE HL_NUMBER
            return 31; // red
        case 8:        // DEFINE HL_MATCH
            return 34; // blue
        default:
            return 37; // white
    }
}

// Select the syntax highlight scheme depending on the filename,
// setting it in the global state E.syntax.
void editorSelectSyntaxHighlight(char* filename) {
    for (unsigned int j = 0; j < HLDB_ENTRIES; j++) {
        struct editorSyntax* s = HLDB + j;
        unsigned int i = 0;
        while (s->filematch[i]) {
            char* p;
            int patlen = strlen(s->filematch[i]);
            if ((p = strstr(filename, s->filematch[i])) != 0) { // DEFINE NULL
                if (s->filematch[i][0] != '.' || p[patlen] == NULL) {
                    E.syntax = s;
                    return;
                }
            }
            i++;
        }
    }
}

// ======================= Editor rows implementation =======================

// Update the rendered version and the syntax highlight of a row.
void editorUpdateRow(struct erow* row) {
    unsigned int tabs = 0;
    unsigned int nonprint = 0;
    int j;
    int idx;

    // Create a version of the row we can directly print on the screen,
    // respecting tabs, substituting non printable characters with '?'.
    free(row->render);
    for (j = 0; j < row->size; j++)
        if (row->chars[j] == TAB)
            tabs++;

    unsigned long allocsize = (unsigned long)row->size + tabs * 8 + nonprint * 9 + 1;
    if (allocsize > 4294967295u) {
        print("Some line of the edited file is too long for kilo\n");
        exit(1);
    }

    row->render = malloc(row->size + tabs * 8 + nonprint * 9 + 1);
    idx = 0;
    for (j = 0; j < row->size; j++) {
        if (row->chars[j] == TAB) {
            row->render[idx++] = ' ';
            while ((idx + 1) % 8 != 0)
                row->render[idx++] = ' ';
        }
        else {
            row->render[idx++] = row->chars[j];
        }
    }
    row->rsize = idx;
    row->render[idx] = NULL;

    // Update the syntax highlighting attributes of the row.
    editorUpdateSyntax(row);
}

// Insert a row at the specified position, shifting the other rows on the bottom
// if required.
void editorInsertRow(int at, char* s, unsigned long len) {
    if (at > E.numrows)
        return;
    E.row = realloc(E.row, sizeof(struct erow) * (E.numrows + 1));
    if (at != E.numrows) {
        memmove(E.row + at + 1, E.row + at, sizeof(E.row[0]) * (E.numrows - at));
        for (int j = at + 1; j <= E.numrows; j++)
            E.row[j].idx++;
    }
    E.row[at].size = len;
    E.row[at].chars = malloc(len + 1);
    memcpy(E.row[at].chars, s, len + 1);
    E.row[at].hl = 0; // DEFINE NULL
    E.row[at].hl_oc = 0;
    E.row[at].render = 0; // DEFINE NULL
    E.row[at].rsize = 0;
    E.row[at].idx = at;
    editorUpdateRow(E.row + at);
    E.numrows++;
    E.dirty++;
}

// Free row's heap allocated stuff.
void editorFreeRow(struct erow* row) {
    free(row->render);
    free(row->chars);
    free(row->hl);
}

// Remove the row at the specified position, shifting the remainign on the
// top.
void editorDelRow(int at) {
    struct erow* row;

    if (at >= E.numrows)
        return;
    row = E.row + at;
    editorFreeRow(row);
    memmove(E.row + at, E.row + at + 1, sizeof(E.row[0]) * (E.numrows - at - 1));
    for (int j = at; j < E.numrows - 1; j++)
        E.row[j].idx++;
    E.numrows--;
    E.dirty++;
}

// Turn the editor rows into a single heap-allocated string.
// Returns the pointer to the heap-allocated string and populate the
// integer pointed by 'buflen' with the size of the string, escluding
// the final nulterm.
char* editorRowsToString(int* buflen) {
    char* buf = 0; // DEFINE NULL
    char* p;
    int totlen = 0;
    int j;

    // Compute count of bytes
    for (j = 0; j < E.numrows; j++)
        totlen += E.row[j].size + 1; // +1 is for "\n" at end of every row
    *buflen = totlen;
    totlen++; // Also make space for nulterm

    p = (buf = malloc(totlen));
    for (j = 0; j < E.numrows; j++) {
        memcpy(p, E.row[j].chars, E.row[j].size);
        p += E.row[j].size;
        *p = '\n';
        p++;
    }
    *p = NULL;
    return buf;
}

// Insert a character at the specified position in a row, moving the remaining
// chars on the right if needed.
void editorRowInsertChar(struct erow* row, int at, int c) {
    if (at > row->size) {
        // Pad the string with spaces if the insert location is outside the
        // current length by more than a single character.
        int padlen = at - row->size;
        // In the next line +2 means: new char and null term.
        row->chars = realloc(row->chars, row->size + padlen + 2);
        memset(row->chars + row->size, ' ', padlen);
        row->chars[row->size + padlen + 1] = NULL;
        row->size += padlen + 1;
    }
    else {
        // If we are in the middle of the string just make space for 1 new
        // char plus the (already existing) null term.
        row->chars = realloc(row->chars, row->size + 2);
        memmove(row->chars + at + 1, row->chars + at, row->size - at + 1);
        row->size++;
    }
    row->chars[at] = c;
    editorUpdateRow(row);
    E.dirty++;
}

// Append the string 's' at the end of a row
void editorRowAppendString(struct erow* row, char* s, unsigned long len) {
    row->chars = realloc(row->chars, row->size + len + 1);
    memcpy(row->chars + row->size, s, len);
    row->size += len;
    row->chars[row->size] = NULL;
    editorUpdateRow(row);
    E.dirty++;
}

// Delete the character at offset 'at' from the specified row.
void editorRowDelChar(struct erow* row, int at) {
    if (row->size <= at)
        return;
    memmove(row->chars + at, row->chars + at + 1, row->size - at);
    editorUpdateRow(row);
    row->size--;
    E.dirty++;
}

// Insert the specified char at the current prompt position.
void editorInsertChar(int c) {
    int filerow = E.rowoff + E.cy;
    int filecol = E.coloff + E.cx;
    struct erow* row = (filerow >= E.numrows) ? 0 : &E.row[filerow]; // DEFINE NULL

    // If the row where the cursor is currently located does not exist in our
    // logical representaion of the file, add enough empty rows as needed.
    if (!row) {
        while (E.numrows <= filerow)
            editorInsertRow(E.numrows, "", 0);
    }
    row = &E.row[filerow];
    editorRowInsertChar(row, filecol, c);
    if (E.cx == E.screencols - 1)
        E.coloff++;
    else
        E.cx++;
    E.dirty++;
}

// Inserting a newline is slightly complex as we have to handle inserting a
// newline in the middle of a line, splitting the line as needed.
void editorInsertNewline(void) {
    int filerow = E.rowoff + E.cy;
    int filecol = E.coloff + E.cx;
    struct erow* row = (filerow >= E.numrows) ? 0 : &E.row[filerow]; // DEFINE NULL

    if (!row) {
        if (filerow == E.numrows) {
            editorInsertRow(filerow, "", 0);
            goto fixcursor;
        }
        return;
    }
    // If the cursor is over the current line size, we want to conceptually
    // think it's just over the last character.
    if (filecol >= row->size)
        filecol = row->size;
    if (filecol == 0) {
        editorInsertRow(filerow, "", 0);
    }
    else {
        // We are in the middle of a line. Split it between two rows.
        editorInsertRow(filerow + 1, row->chars + filecol, row->size - filecol);
        row = &E.row[filerow];
        row->chars[filecol] = NULL;
        row->size = filecol;
        editorUpdateRow(row);
    }
fixcursor:
    if (E.cy == E.screenrows - 1) {
        E.rowoff++;
    }
    else {
        E.cy++;
    }
    E.cx = 0;
    E.coloff = 0;
}

// Delete the char at the current prompt position.
void editorDelChar(void) {
    int filerow = E.rowoff + E.cy;
    int filecol = E.coloff + E.cx;
    struct erow* row = (filerow >= E.numrows) ? 0 : &E.row[filerow]; // DEFINE NULL

    if (!row || (filecol == 0 && filerow == 0))
        return;
    if (filecol == 0) {
        // Handle the case of column 0, we need to move the current line
        // on the right of the previous one.
        filecol = E.row[filerow - 1].size;
        editorRowAppendString(&E.row[filerow - 1], row->chars, row->size);
        editorDelRow(filerow);
        row = 0; // DEFINE NULL
        if (E.cy == 0)
            E.rowoff--;
        else
            E.cy--;
        E.cx = filecol;
        if (E.cx >= E.screencols) {
            int shift = (E.screencols - E.cx) + 1;
            E.cx -= shift;
            E.coloff += shift;
        }
    }
    else {
        editorRowDelChar(row, filecol - 1);
        if (E.cx == 0 && E.coloff)
            E.coloff--;
        else
            E.cx--;
    }
    if (row)
        editorUpdateRow(row);
    E.dirty++;
}

// Load the specified program in the editor memory and returns 0 on success
// or 1 on error.
int editorOpen(char* filename) {
    struct FILE* fp;

    E.dirty = 0;
    free(E.filename);
    unsigned long fnlen = strlen(filename) + 1;
    E.filename = malloc(fnlen);
    memcpy(E.filename, filename, fnlen);

    fp = fopen(filename, "r");
    if (!fp) {
        if (get_errno() != ENOENT) {
            perror("Opening file");
            exit(1);
        }
        return 1;
    }

    char* line = 0; // DEFINE NULL
    unsigned long linecap = 0;
    long linelen;
    while ((linelen = getline(&line, &linecap, fp)) != -1) {
        if (linelen && (line[linelen - 1] == '\n' || line[linelen - 1] == '\r'))
            line[--linelen] = NULL;
        editorInsertRow(E.numrows, line, linelen);
    }
    free(line);
    fclose(fp);
    E.dirty = 0;
    return 0;
}

// Save the current file on disk. Return 0 on success, 1 on error.
int editorSave(void) {
    int len;
    char* buf = editorRowsToString(&len);
    int fd = open(E.filename, O_RDWR | O_CREAT, COPYMODE);
    if (fd == -1)
        goto writeerr;

    // Use truncate + a single write(2) call in order to make saving
    // a bit safer, under the limits of what we can do in a small editor.
    if (ftruncate(fd, len) == -1)
        goto writeerr;
    if (write(fd, buf, len) != len)
        goto writeerr;

    close(fd);
    free(buf);
    E.dirty = 0;
    char sd[20] = {0};
    editorSetStatusMessage(fmt2(ltostr(sd, len), " bytes written on disk"));
    return 0;

writeerr:
    free(buf);
    if (fd != -1)
        close(fd);
    editorSetStatusMessage(fmt2("Can't save! I/O error: ", strerror(get_errno())));
    return 1;
}

// ============================= Terminal update ============================

// We define a very simple "append buffer" structure, that is an heap
// allocated string where we can append to. This is useful in order to
// write all the escape sequences in a buffer and flush them to the standard
// output in a single call, to avoid flickering effects.
struct abuf {
    char* b;
    int len;
};

// #define ABUF_INIT { NULL, 0 }

void abAppend(struct abuf* ab, char* s, int len) {
    char* new = realloc(ab->b, ab->len + len);

    if (new == 0) // DEFINE NULL
        return;
    memcpy(new + ab->len, s, len);
    ab->b = new;
    ab->len += len;
}

void abFree(struct abuf* ab) { free(ab->b); }

// This function writes the whole screen using VT100 escape characters
// starting from the logical state of the editor in the global state 'E'.
void editorRefreshScreen(void) {
    int y;
    struct erow* r;
    char buf[32];
    char sd1[20] = {0};
    char sd2[20] = {0};
    struct abuf ab = {0, 0}; // DEFINE ABUF_INIT; NULL

    abAppend(&ab, x1b_hide_cur, 6);      // Hide cursor.
    abAppend(&ab, x1b_move_cur_home, 3); // Go home.
    for (y = 0; y < E.screenrows; y++) {
        int filerow = E.rowoff + y;

        if (filerow >= E.numrows) {
            if (E.numrows == 0 && y == E.screenrows / 3) {
                char welcome[80];
                int welcomelen = snprint(
                    welcome, sizeof(welcome), fmt3("Kilo editor -- version ", KILO_VERSION, X1B_erase_cur_crlf));
                int padding = (E.screencols - welcomelen) / 2;
                if (padding) {
                    abAppend(&ab, "~", 1);
                    padding--;
                }
                while (padding--)
                    abAppend(&ab, " ", 1);
                abAppend(&ab, welcome, welcomelen);
            }
            else {
                abAppend(&ab, x1b_put_blank_line, 7);
            }
            continue;
        }

        r = &E.row[filerow];

        int len = r->rsize - E.coloff;
        int current_color = -1;
        if (len > 0) {
            if (len > E.screencols)
                len = E.screencols;
            char* c = r->render + E.coloff;
            unsigned char* hl = r->hl + E.coloff;
            int j;
            for (j = 0; j < len; j++) {
                if (hl[j] == HL_NONPRINT) {
                    char sym;
                    abAppend(&ab, x1b_set_inv_mode, 4);
                    if (c[j] <= 26)
                        sym = '@' + c[j];
                    else
                        sym = '?';
                    abAppend(&ab, &sym, 1);
                    abAppend(&ab, x1b_reset_modes, 4);
                }
                else if (hl[j] == HL_NORMAL) {
                    if (current_color != -1) {
                        abAppend(&ab, x1b_set_def_fgcol, 5);
                        current_color = -1;
                    }
                    abAppend(&ab, c + j, 1);
                }
                else {
                    int color = editorSyntaxToColor(hl[j]);
                    if (color != current_color) {
                        char buf[16];
                        int clen = snprint(buf, sizeof(buf), fmt3(x1b_prefix, ltostr(sd1, color), "m"));
                        current_color = color;
                        abAppend(&ab, buf, clen);
                    }
                    abAppend(&ab, c + j, 1);
                }
            }
        }
        abAppend(&ab, x1b_set_def_fgcol, 5);
        abAppend(&ab, x1b_erase_cur, 4);
        abAppend(&ab, "\r\n", 2);
    }

    // Create a two rows status. First row:
    abAppend(&ab, x1b_erase_cur, 4);
    abAppend(&ab, x1b_set_inv_mode, 4);
    char status[80];
    char rstatus[80];
    int len = snprint(status, sizeof(status),
        fmt5(E.filename, " - ", ltostr(sd1, E.numrows), " lines ", E.dirty ? "(modified)" : ""));
    int rlen = snprint(rstatus, sizeof(rstatus), fmt3(ltostr(sd2, E.rowoff + E.cy + 1), "/", sd1));
    if (len > E.screencols)
        len = E.screencols;
    abAppend(&ab, status, len);
    while (len < E.screencols) {
        if (E.screencols - len == rlen) {
            abAppend(&ab, rstatus, rlen);
            break;
        }
        else {
            abAppend(&ab, " ", 1);
            len++;
        }
    }
    abAppend(&ab, x1b_reset_modes_clrf, 6);

    // Second row depends on E.statusmsg and the status message update time.
    abAppend(&ab, x1b_erase_cur, 4);
    int msglen = strlen(E.statusmsg);
    if (msglen && time(0) - E.statusmsg_time < 5) // DEFINE NULL
        abAppend(&ab, E.statusmsg, msglen <= E.screencols ? msglen : E.screencols);

    // Put cursor at its current position. Note that the horizontal position
    // at which the cursor is displayed may be different compared to 'E.cx'
    // because of TABs.
    int j;
    int cx = 1;
    int filerow = E.rowoff + E.cy;
    struct erow* row = (filerow >= E.numrows) ? 0 : &E.row[filerow]; // DEFINE NULL
    if (row) {
        for (j = E.coloff; j < (E.cx + E.coloff); j++) {
            if (j < row->size && row->chars[j] == TAB)
                cx += 7 - ((cx) % 8);
            cx++;
        }
    }
    snprint(buf, sizeof(buf), fmt5(x1b_prefix, ltostr(sd1, E.cy + 1), ";", ltostr(sd2, cx), "H"));
    abAppend(&ab, buf, strlen(buf));
    abAppend(&ab, x1b_show_cur, 6); // Show cursor.
    write(STDOUT_FILENO, ab.b, ab.len);
    abFree(&ab);
}

// Set an editor status message for the second line of the status, at the
// end of the screen.
void editorSetStatusMessage(char* format) {
    snprint(E.statusmsg, sizeof(E.statusmsg), format);
    E.statusmsg_time = time(0); // DEFINE NULL
}

// =============================== Find mode ================================

int KILO_QUERY_LEN = 256; // DEFINE

void editorFind(int fd) {
    char query[257] = {0}; // DEFINE KILO_QUERY_LEN + 1
    int qlen = 0;
    int last_match = -1;    // Last line where a match was found. -1 for none.
    int find_next = 0;      // if 1 search next, if -1 search prev.
    int saved_hl_line = -1; // No saved HL
    char* saved_hl = 0;     // DEFINE NULL

    // #define FIND_RESTORE_HL
    //     do {
    //         if (saved_hl) {
    //             memcpy(E.row[saved_hl_line].hl, saved_hl, E.row[saved_hl_line].rsize);
    //             free(saved_hl);
    //             saved_hl = NULL;
    //         }
    //     }
    //     while (0)

    // Save the cursor position in order to restore it later.
    int saved_cx = E.cx;
    int saved_cy = E.cy;
    int saved_coloff = E.coloff;
    int saved_rowoff = E.rowoff;

    while (1) {
        editorSetStatusMessage(fmt3("Search: ", query, " (Use ESC/Arrows/Enter)"));
        editorRefreshScreen();

        int c = editorReadKey(fd);
        if (c == DEL_KEY || c == CTRL_H || c == BACKSPACE) {
            if (qlen != 0)
                query[--qlen] = NULL;
            last_match = -1;
        }
        else if (c == ESC || c == ENTER) {
            if (c == ESC) {
                E.cx = saved_cx;
                E.cy = saved_cy;
                E.coloff = saved_coloff;
                E.rowoff = saved_rowoff;
            }
            if (saved_hl) { // DEFINE FIND_RESTORE_HL
                memcpy(E.row[saved_hl_line].hl, saved_hl, E.row[saved_hl_line].rsize);
                free(saved_hl);
                saved_hl = 0; // DEFINE NULL
            }
            editorSetStatusMessage("");
            return;
        }
        else if (c == ARROW_RIGHT || c == ARROW_DOWN) {
            find_next = 1;
        }
        else if (c == ARROW_LEFT || c == ARROW_UP) {
            find_next = -1;
        }
        else if (isprint(c)) {
            if (qlen < KILO_QUERY_LEN) {
                query[qlen++] = c;
                query[qlen] = NULL;
                last_match = -1;
            }
        }

        // Search occurrence.
        if (last_match == -1)
            find_next = 1;
        if (find_next) {
            char* match = 0; // DEFINE NULL
            int match_offset = 0;
            int i;
            int current = last_match;

            for (i = 0; i < E.numrows; i++) {
                current += find_next;
                if (current == -1)
                    current = E.numrows - 1;
                else if (current == E.numrows)
                    current = 0;
                match = strstr(E.row[current].render, query);
                if (match) {
                    match_offset = match - E.row[current].render;
                    break;
                }
            }
            find_next = 0;

            // Highlight
            if (saved_hl) { // DEFINE FIND_RESTORE_HL
                memcpy(E.row[saved_hl_line].hl, saved_hl, E.row[saved_hl_line].rsize);
                free(saved_hl);
                saved_hl = 0; // DEFINE NULL
            }

            if (match) {
                struct erow* row = &E.row[current];
                last_match = current;
                if (row->hl) {
                    saved_hl_line = current;
                    saved_hl = malloc(row->rsize);
                    memcpy(saved_hl, row->hl, row->rsize);
                    memset(row->hl + match_offset, HL_MATCH, qlen);
                }
                E.cy = 0;
                E.cx = match_offset;
                E.rowoff = current;
                E.coloff = 0;
                // Scroll horizontally as needed.
                if (E.cx > E.screencols) {
                    int diff = E.cx - E.screencols;
                    E.cx -= diff;
                    E.coloff += diff;
                }
            }
        }
    }
}

// ========================= Editor events handling  ========================

// Handle cursor position change because arrow keys were pressed.
void editorMoveCursor(int key) {
    int filerow = E.rowoff + E.cy;
    int filecol = E.coloff + E.cx;
    int rowlen;
    struct erow* row = (filerow >= E.numrows) ? 0 : &E.row[filerow]; // DEFINE NULL

    switch (key) {
        case 1000: // DEFINE ARROW_LEFT
            if (E.cx == 0) {
                if (E.coloff) {
                    E.coloff--;
                }
                else {
                    if (filerow > 0) {
                        E.cy--;
                        E.cx = E.row[filerow - 1].size;
                        if (E.cx > E.screencols - 1) {
                            E.coloff = E.cx - E.screencols + 1;
                            E.cx = E.screencols - 1;
                        }
                    }
                }
            }
            else {
                E.cx -= 1;
            }
            break;
        case 1001: // DEFINE ARROW_RIGHT
            if (row && filecol < row->size) {
                if (E.cx == E.screencols - 1) {
                    E.coloff++;
                }
                else {
                    E.cx += 1;
                }
            }
            else if (row && filecol == row->size) {
                E.cx = 0;
                E.coloff = 0;
                if (E.cy == E.screenrows - 1) {
                    E.rowoff++;
                }
                else {
                    E.cy += 1;
                }
            }
            break;
        case 1002: // DEFINE ARROW_UP
            if (E.cy == 0) {
                if (E.rowoff)
                    E.rowoff--;
            }
            else {
                E.cy -= 1;
            }
            break;
        case 1003: // DEFINE ARROW_DOWN
            if (filerow < E.numrows) {
                if (E.cy == E.screenrows - 1) {
                    E.rowoff++;
                }
                else {
                    E.cy += 1;
                }
            }
            break;
    }
    // Fix cx if the current line has not enough chars.
    filerow = E.rowoff + E.cy;
    filecol = E.coloff + E.cx;
    row = (filerow >= E.numrows) ? 0 : &E.row[filerow]; // DEFINE NULL
    rowlen = row ? row->size : 0;
    if (filecol > rowlen) {
        E.cx -= filecol - rowlen;
        if (E.cx < 0) {
            E.coloff += E.cx;
            E.cx = 0;
        }
    }
}

// Process events arriving from the standard input, which is, the user
// is typing stuff on the terminal.
int KILO_QUIT_TIMES = 3; // DEFINE
void editorProcessKeypress(int fd) {
    // When the file is modified, requires Ctrl-q to be pressed N times
    // before actually quitting.
    static int quit_times = 3; // DEFINE KILO_QUIT_TIMES

    int c = editorReadKey(fd);
    switch (c) {
        case 13: // DEFINE ENTER // Enter
            editorInsertNewline();
            break;
        case 3: // DEFINE CTRL_C // Ctrl-c
            // We ignore ctrl-c, it can't be so simple to lose the changes
            // to the edited file.
            break;
        case 17: // DEFINE CTRL_Q // Ctrl-q
            // Quit if the file was already saved.
            if (E.dirty && quit_times) {
                char sd[20] = {0};
                editorSetStatusMessage(fmt3("WARNING!!! File has unsaved changes. Press Ctrl-Q ",
                    ltostr(sd, quit_times), " more times to quit."));
                quit_times--;
                return;
            }
            exit(0);
            break;
        case 19: // DEFINE CTRL_S // Ctrl-s
            editorSave();
            break;
        case 6: // DEFINE CTRL_F
            editorFind(fd);
            break;
        case 127:  // DEFINE BACKSPACE // Backspace
        case 8:    // DEFINE CTRL_H    // Ctrl-h
        case 1004: // DEFINE DEL_KEY
            editorDelChar();
            break;
        case 1007: // DEFINE PAGE_UP
        case 1008: // DEFINE PAGE_DOWN
            if (c == PAGE_UP && E.cy != 0)
                E.cy = 0;
            else if (c == PAGE_DOWN && E.cy != E.screenrows - 1)
                E.cy = E.screenrows - 1;
            {
                int times = E.screenrows;
                while (times--)
                    editorMoveCursor(c == PAGE_UP ? ARROW_UP : ARROW_DOWN);
            }
            break;

        case 1002: // DEFINE ARROW_UP
        case 1003: // DEFINE ARROW_DOWN
        case 1000: // DEFINE ARROW_LEFT
        case 1001: // DEFINE ARROW_RIGHT
            editorMoveCursor(c);
            break;
        case 12: // DEFINE CTRL_L // ctrl+l, clear screen
            // Just refresht the line as side effect.
            break;
        case 27: // DEFINE ESC
            // Nothing to do for ESC in this mode.
            break;
        default:
            editorInsertChar(c);
            break;
    }

    quit_times = KILO_QUIT_TIMES; // Reset it to the original value.
}

int editorFileWasModified(void) { return E.dirty; }

void updateWindowSize(void) {
    if (getWindowSize(STDIN_FILENO, STDOUT_FILENO, &E.screenrows, &E.screencols) == -1) {
        perror("Unable to query the screen for size (columns / rows)");
        exit(1);
    }
    E.screenrows -= 2; // Get room for status bar.
}

void handleSigWinCh(void) {
    updateWindowSize();
    if (E.cy > E.screenrows)
        E.cy = E.screenrows - 1;
    if (E.cx > E.screencols)
        E.cx = E.screencols - 1;
    editorRefreshScreen();
}

void signal_func(int sig) {
    if (sig == SIGWINCH) {
        handleSigWinCh();
    }
}

void initEditor(void) {
    E.cx = 0;
    E.cy = 0;
    E.rowoff = 0;
    E.coloff = 0;
    E.numrows = 0;
    E.row = 0; // DEFINE NULL
    E.dirty = 0;
    E.filename = 0; // DEFINE NULL
    E.syntax = 0;   // DEFINE NULL
    updateWindowSize();
    signal_f(SIGWINCH);
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprint(get_stderr(), "Usage: kilo <filename>\n");
        exit(1);
    }

    initEditor();
    editorSelectSyntaxHighlight(argv[1]);
    editorOpen(argv[1]);
    enableRawMode(STDIN_FILENO);
    editorSetStatusMessage("HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find");
    while (1) {
        editorRefreshScreen();
        editorProcessKeypress(STDIN_FILENO);
    }
    return 0;
}

// Copyright 2026 Romain Ducrocq
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// -----------------------------------------------------------------------
//
// Copyright (C) 2016 Salvatore Sanfilippo <antirez at gmail dot com>
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//  *  Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
