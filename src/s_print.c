/* Copyright (c) 1997-1999 Miller Puckette.
* For information on usage and redistribution, and for a DISCLAIMER OF ALL
* WARRANTIES, see the file, "LICENSE.txt," in this distribution.  */

#include "m_pd.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include "s_stuff.h"
#include "m_private_utils.h"

#ifdef _WIN32
#ifndef PD_FWPRINTF_NARROW_FORMATTER
#if __USE_MINGW_ANSI_STDIO
    /* This is a workaround for a bug in the old msvcrt.dll used by MinGW */
    #define PD_FWPRINTF_NARROW_FORMATTER L"%s"
#else
    /* Covers modern C runtimes on MSYS2 & MSVC */
    #define PD_FWPRINTF_NARROW_FORMATTER L"%S"
#endif
#endif /* PD_FWPRINTF_NARROW_FORMATTER */
#endif /* _WIN32 */

t_printhook sys_printhook = NULL;
int sys_printtostderr;

#ifdef _WIN32

    /* NB: Unlike vsnprintf(), _vsnprintf() does *not* null-terminate
    the output if the resulting string is too large to fit into the buffer.
    Also, it just returns -1 instead of the required number of bytes.
    Strictly speaking, the UCRT in Windows 10 actually contains a standard-
    conforming vsnprintf() function that is not just an alias for _vsnprintf().
    However, MinGW traditionally links against the old msvcrt.dll runtime library.
    Recent versions of MinGW seem to have their own (standard-conformating)
    implementation of vsnprintf(), but to ensure portability we rather use our
    own implementation for all Windows builds. */
int pd_vsnprintf(char *buf, size_t size, const char *fmt, va_list argptr)
{
    int ret = _vsnprintf(buf, size, fmt, argptr);
    if (ret < 0)
    {
            /* null-terminate the buffer and get the required number of bytes. */
        ret = _vscprintf(fmt, argptr);
        buf[size - 1] = '\0';
    }
    return ret;
}

int pd_snprintf(char *buf, size_t size, const char *fmt, ...)
{
    int ret;
    va_list ap;
    va_start(ap, fmt);
    ret = pd_vsnprintf(buf, size, fmt, ap);
    va_end(ap);
    return ret;
}

#else

int pd_vsnprintf(char *buf, size_t size, const char *fmt, va_list argptr)
{
    return vsnprintf(buf, size, fmt, argptr);
}

int pd_snprintf(char *buf, size_t size, const char *fmt, ...)
{
    int ret;
    va_list ap;
    va_start(ap, fmt);
    ret = vsnprintf(buf, size, fmt, ap);
    va_end(ap);
    return ret;
}

#endif

/* escape characters for tcl/tk */
char* pdgui_strnescape(char *dst, size_t dstlen, const char *src, size_t srclen)
{
    unsigned ptin = 0, ptout = 0;
    if(!dst || !src)return 0;
    while(1)
    {
        int c = src[ptin];
        if (c == '\\' || c == '{' || c == '}' || c == '[' || c == ']') {
            dst[ptout++] = '\\';
            if (dstlen && ptout >= dstlen){
                dst[ptout-1] = 0;
                break;
            }
        }
        dst[ptout] = c;
        ptin++;
        ptout++;
        if (c==0) break;
        if (srclen && ptin  >= srclen) break;
        if (dstlen && ptout >= dstlen) break;
    }

    if(!dstlen || ptout < dstlen)
        dst[ptout]=0;
    else
        dst[dstlen-1]=0;

    return dst;
}

static void dopost(const char *s)
{
    if (STUFF->st_printhook)
        (*STUFF->st_printhook)(s);
    else if (sys_printtostderr || !sys_havetkproc())
    {
#ifdef _WIN32
        fwprintf(stderr, PD_FWPRINTF_NARROW_FORMATTER, s);
        fflush(stderr);
#else
        fprintf(stderr, "%s", s);
#endif
    }
    else
    {
        pdgui_vmess("::pdwindow::post", "s", s);
    }
}

static void doerror(const void *object, const char *s)
{
    char upbuf[MAXPDSTRING];
    upbuf[MAXPDSTRING-1]=0;

    // what about sys_printhook_error ?
    if (STUFF->st_printhook)
    {
        pd_snprintf(upbuf, MAXPDSTRING-1, "error: %s", s);
        (*STUFF->st_printhook)(upbuf);
    }
    else if (sys_printtostderr || !sys_havetkproc())
    {
#ifdef _WIN32
        fwprintf(stderr, L"error: " PD_FWPRINTF_NARROW_FORMATTER, s);
        fflush(stderr);
#else
        fprintf(stderr, "error: %s", s);
#endif
    }
    else
        pdgui_vmess("::pdwindow::logpost", "ois",
                  object, PD_ERROR, s);
}

static void dologpost(const void *object, const int level, const char *s)
{
    char upbuf[MAXPDSTRING];
    upbuf[MAXPDSTRING-1]=0;
        /* if it's a verbose message and we aren't set to 'verbose' just do
            nothing */
    if (level >= PD_VERBOSE && !sys_verbose)
        return;
    // what about sys_printhook_verbose ?
    if (STUFF->st_printhook)
    {
        pd_snprintf(upbuf, MAXPDSTRING-1, "verbose(%d): %s", level, s);
        (*STUFF->st_printhook)(upbuf);
    }
    else if (sys_printtostderr || !sys_havetkproc())
    {
#ifdef _WIN32
        fwprintf(stderr, L"verbose(%d): " PD_FWPRINTF_NARROW_FORMATTER, level, s);
        fflush(stderr);
#else
        fprintf(stderr, "%s", s);
#endif
    }
    else
        pdgui_vmess("::pdwindow::logpost", "ois",
                  object, level, s);
}

void logpost(const void *object, int level, const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    if (level > PD_DEBUG && !sys_verbose) return;
    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);
    strcat(buf, "\n");

    dologpost(object, level, buf);
}

void startlogpost(const void *object, const int level, const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    if (level > PD_DEBUG && !sys_verbose) return;
    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);

    dologpost(object, level, buf);
}

/* pd_post is the same as post but less likely to give name clashes when
used in a dynamic library such as a VST plug-in */
void pd_post(const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    t_int arg[8];
    int i;
    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);
    strcat(buf, "\n");

    dopost(buf);
}

void post(const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    t_int arg[8];
    int i;
    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);
    strcat(buf, "\n");

    dopost(buf);
}

void startpost(const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    t_int arg[8];
    int i;
    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);

    dopost(buf);
}

void poststring(const char *s)
{
    dopost(" ");

    dopost(s);
}

void postatom(int argc, const t_atom *argv)
{
    int i;
    for (i = 0; i < argc; i++)
    {
        char buf[MAXPDSTRING];
        atom_string(argv+i, buf, MAXPDSTRING);
        poststring(buf);
    }
}

void postfloat(t_float f)
{
    char buf[80];
    t_atom a;
    SETFLOAT(&a, f);

    postatom(1, &a);
}

void endpost(void)
{
    if (STUFF->st_printhook)
        (*STUFF->st_printhook)("\n");
    else if (sys_printtostderr)
        fprintf(stderr, "\n");
    else post("");
}

  /* keep this in the Pd app for binary extern compatibility but don't
  include in libpd because it conflicts with the posix pd_error(0, ) function. */
#ifdef PD_INTERNAL
EXTERN void error(const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    t_int arg[8];
    int i;

    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);
    strcat(buf, "\n");

    doerror(NULL, buf);
}
#endif

/* deprecated in favor of logpost() */
void verbose(int level, const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;

    if (level > sys_verbose) return;

    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);
    strcat(buf, "\n");

        /* log levels for verbose() traditionally start at -3,
        so we have to adjust it before passing it on to dologpost() */
    dologpost(NULL, level + 3, buf);
}

    /* here's the good way to log errors -- keep a pointer to the
    offending or offended object around so the user can search for it
    later. */

static const void *error_object;
static char error_string[256];

void canvas_finderror(const void *object);

void pd_error(const void *object, const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    t_int arg[8];
    int i;
    static int saidit = 0;

    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);
    strcat(buf, "\n");

    doerror(object, buf);

    if(object) {
        error_object = object;
        strncpy(error_string, buf, 256);
        error_string[255] = 0;
    }

    if (object && !saidit)
    {
        if (sys_havetkproc())
            logpost(NULL, PD_VERBOSE,
                "... you might be able to track this down from the Find menu.");
        saidit = 1;
    }
}

void glob_finderror(t_pd *dummy)
{
    if (!error_object)
        post("no findable error yet");
    else
    {
        post("last trackable error:");
        post("%s", error_string);
        canvas_finderror(error_object);
    }
}

void glob_findinstance(t_pd *dummy, t_symbol*s)
{
    // revert s to (potential) pointer to object
    PD_LONGINTTYPE obj = 0;
    const char*addr;
    int result = 0;
    if(!s || !s->s_name)
        return;
    addr = s->s_name;
    if (!result)
        result = sscanf(addr, PDGUI_FORMAT__OBJECT, &obj);
    if (!result && (('.' == addr[0]) || ('0' == addr[0])))
        result = sscanf(addr+1, "x%lx", &obj);
    if (!result)
        return;

    if(!obj)
        return;

    canvas_finderror((void *)obj);
}

void bug(const char *fmt, ...)
{
    char buf[MAXPDSTRING];
    va_list ap;
    t_int arg[8];
    int i;
    va_start(ap, fmt);
    pd_vsnprintf(buf, MAXPDSTRING-1, fmt, ap);
    va_end(ap);

    pd_error(0, "consistency check failed: %s", buf);
}

    /* don't use these.  They're included for binary compatibility with
    old externs but never worked and now do nothing. */
void sys_logerror(const char *object, const char *s) {}
void sys_unixerror(const char *object) {}
void sys_ouch(void) {}
