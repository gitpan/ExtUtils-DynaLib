#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#ifdef DYNALIB_USE_cdecl
#include "cdecl.c"
#endif
#ifdef DYNALIB_USE_sparc
#include "sparc.c"
#endif
#ifdef DYNALIB_USE_hack30
#include "hack30.c"
#endif

#ifndef DYNALIB_NUM_CALLBACKS
#define DYNALIB_NUM_CALLBACKS 0
#endif

typedef int (*cb_callback) _((int a, ...));
typedef struct {
  SV *coderef;
  char *ret_type;
  char *arg_type;
  cb_callback func;
} cb_entry;

static int cb_call_sub _((int index, int first, va_list ap));

#include "cbfunc.c"

static AV *cb_av_config;
static const cb_callback cb_arr[DYNALIB_NUM_CALLBACKS];

static AV *
cb_init(arr_ref)
SV *arr_ref;
{
  SV *elts[DYNALIB_NUM_CALLBACKS];
  int i;
  cb_entry entry;

  entry.coderef = NULL;
  entry.arg_type = "";
  entry.ret_type = "";
  for (i = 0; i < DYNALIB_NUM_CALLBACKS; i++) {
    entry.func = cb_arr[i];
    elts[i] = newSVpv((char *) &entry, sizeof entry);
  }
  cb_av_config = av_make(DYNALIB_NUM_CALLBACKS, elts);
  return cb_av_config;
}

#if DYNALIB_NUM_CALLBACKS
static int
cb_call_sub(index, first, ap)
int index;
int first;
va_list ap;
{
  dSP;
  I32 nret;
  int i, result;
  STRLEN old_err_len, new_err_len;
  char *arg_type;
  cb_entry *config;

  config = (cb_entry *) SvPV(*av_fetch(cb_av_config, index, 0), na);
  ENTER;
  SAVETMPS;
  PUSHMARK(sp);
  arg_type = config->arg_type;
  if (*arg_type != '\0') {
    switch (*arg_type) {
    case 'i' :
      XPUSHs(sv_2mortal(newSViv((IV) first)));
      break;
    case 'p' :
      if (sizeof (char *) == sizeof (int)) {
	XPUSHs(sv_2mortal(newSVpv((char *) first, 0)));
	break;
      }
    default :
      croak("Can't use '%c' as first argument type in callback", *arg_type);
    }
    for (arg_type++; *arg_type != '\0'; arg_type++) {
      switch (*arg_type) {
      case 'i' :
	XPUSHs(sv_2mortal(newSViv((IV) va_arg(ap, int))));
	break;
      case 'd' :
	XPUSHs(sv_2mortal(newSViv((IV) va_arg(ap, double))));
	break;
      case 'p' :
	XPUSHs(sv_2mortal(newSVpv(va_arg(ap, char *), 0)));
	break;
      default :
	croak("Can't use '%c' as argument type in callback", *arg_type);
      }
    }
  }
  PUTBACK;

  if (in_eval) {
    /*
     * XXX The whole issue of G_KEEPERR and `eval's is very confusing to me.
     * For example, we should be able to tell whether or not we are in
     * cleanup code that follows a die.  We can't tell just by looking at $@,
     * since it may be left over from a previous eval.
     *
     * If we're not in cleanup, we should clear $@/errgv before we call the
     * sub.  The way this code works now, any error string left over from a
     * completed eval is wrongly included in our croak message.
     *
     * It can also produce weirdness when used with Carp::confess.
     */
    SvPV(GvSV(errgv), old_err_len);
    nret = perl_call_sv(config->coderef, G_SCALAR | G_EVAL | G_KEEPERR);
    SPAGAIN;
    SvPV(GvSV(errgv), new_err_len);
    if (new_err_len > old_err_len) {
      char *msg = SvPV(GvSV(errgv),na);
      static char prefix[] = "\t(in cleanup) ";  /* from pp_ctl.c */

      if (old_err_len == 0 && strnEQ(msg, prefix, (sizeof prefix) - 1)) {
	msg += (sizeof prefix) - 1;
	croak("In callback: %s", msg);
      }
      else {
	croak("%s", msg);
      }
    }
  }
  else {
    nret = perl_call_sv(config->coderef, G_SCALAR);
    SPAGAIN;
  }
  if (nret != 1) {
    /* don't know if this can ever happen... */
    croak("Call to callback failed\n");
  }
  switch (*(config->ret_type)) {
  case '\0' :
  case 'i' :
    result = POPi;
    break;
  /*
   * Returning a pointer is impossible to do safely, it seems.
  case 'p' :
    if (sizeof (char *) == sizeof (int)) {
      result = (int) POPp;
      break;
    }
   */
  default :
    croak("Can't use '%s' as return type in callback", config->ret_type);
  }
  PUTBACK;
  FREETMPS;
  LEAVE;
  return result;
}
#endif  /* DYNALIB_NUM_CALLBACKS != 0 */


MODULE = ExtUtils::DynaLib  PACKAGE = ExtUtils::DynaLib

void
Poke(dest, data)
	void *	dest
	SV *	data
	CODE:
	{
	  STRLEN len;
	  char *source;
	  if (SvPOK(data)) {
	    source = SvPV(data, len);
	    Copy(source, dest, len, char);
	  }
	}

INCLUDE: conv.xsi

char *
default_convention()
	CODE:
	RETVAL = DYNALIB_DEFAULT_CONV;
	OUTPUT:
	RETVAL

BOOT:
	/* Setup the callback config array. */
#if PATCHLEVEL >= 4
	sv_setsv(SvRV(ST(2)), newRV_noinc((SV*) cb_init(ST(2))));
#else
	sv_setsv(SvRV(ST(2)), newRV((SV*) cb_init(ST(2))));
#endif
