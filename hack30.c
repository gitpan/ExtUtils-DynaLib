/* horrible hacks here. */

#ifndef MAXPSEU
#define MAXPSEU 30
#endif

static int
hack30_pray(ax, items, func)
I32 ax;
I32 items;
void *func;
{
  STRLEN arg_len;
  void *arg_scalar;
  int i = 1;
  int nbytes = 0;
  int pseu[MAXPSEU];
  int check_len;

  for (i = 1; i < items; i++) {
    arg_scalar = SvPV(ST(i), arg_len);
    check_len = nbytes + arg_len;
    if (check_len > sizeof pseu) {
      croak("Too many arguments.  The hack30 calling convention accepts up to %d int-size arguments.", MAXPSEU);
    }
    Copy(arg_scalar, &((char *) (&pseu[0]))[nbytes],
	 arg_len, char);
    nbytes = check_len;
  }
  if (nbytes > 6 * sizeof (int)) {
    return (*((int (*)()) func))
      (pseu[0], pseu[1], pseu[2], pseu[3], pseu[4], pseu[5],
       pseu[6], pseu[7], pseu[8], pseu[9], pseu[10], pseu[11],
       pseu[12], pseu[13], pseu[14], pseu[15], pseu[16], pseu[17],
       pseu[18], pseu[19], pseu[20], pseu[21], pseu[22], pseu[23],
       pseu[24], pseu[25], pseu[26], pseu[27], pseu[28], pseu[29]);
  }
  else {
    return (*((int (*)()) func))
      (pseu[0], pseu[1], pseu[2], pseu[3], pseu[4], pseu[5]);
  }
}

#define hack30_CALL(func, type)						\
    ((*((type (*)(I32, I32, void *)) hack30_pray))(ax,items,func))
