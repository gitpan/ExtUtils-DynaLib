static AV *cb_av_config;
static const cb_callback cb_arr[];

static AV *
cb_init(arr_ref)
SV *arr_ref;
{
  SV *elts[NUM_CALLBACKS];
  int i;
  cb_entry entry;

  entry.coderef = NULL;
  entry.arg_type = "";
  entry.ret_type = "";
  for (i = 0; i < NUM_CALLBACKS; i++) {
    entry.func = cb_arr[i];
    elts[i] = newSVpv((char *) &entry, sizeof entry);
  }
  cb_av_config = av_make(NUM_CALLBACKS, elts);
  return cb_av_config;
}

static int
cb_call_sub(index, first, ap)
int index;
int first;
va_list ap;
{
  dSP;
  I32 nret;
  int i, result;
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
  nret = perl_call_sv(config->coderef, G_SCALAR | G_EVAL | G_KEEPERR);
  SPAGAIN;
  if (nret != 1) {
    croak("Call to callback failed\n");
  }
  switch (*(config->ret_type)) {
  case '\0' :
  case 'i' :
    result = POPi;
    break;
  case 'p' :
    if (sizeof (char *) == sizeof (int)) {
      result = (int) POPp;
      break;
    }
  default :
    croak("Can't use '%c' as return type in callback", *(config->ret_type));
  }
  PUTBACK;
  FREETMPS;
  LEAVE;
  return result;
}
