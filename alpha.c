#include <alloca.h>

/*
 * Convert Perl sub args to C args and pass them to (*func)().
 */
static long
alpha_pray(ax, items, func)
I32 ax;		/* used by the ST() macro */
I32 items;
int (*func)();
{
  STRLEN arg_len;
  char *arg_scalar;
  long pseu[] = { 0, 0, 0, 0, 0, 0 };
  long *lptr;
  int i;

  for (i = DYNALIB_ARGSTART; i < items; i++) {
    /* Fetch next (packed) Perl arg */
    arg_scalar = SvPV(ST(i), arg_len);
    /* Convert to 8-byte for placement in register or on stack */
    if (i < 6 + DYNALIB_ARGSTART) {
      lptr = &pseu[i - DYNALIB_ARGSTART];
    }
    else if (i == 6 + DYNALIB_ARGSTART) {
      lptr = (long *) alloca((items - (6 + DYNALIB_ARGSTART)) * sizeof (long));
    }
    else {
      lptr ++;
    }
    switch (arg_len) {
    case 1:
      *lptr = (long) (*arg_scalar);
      break;
    case SHORTSIZE:
      *lptr = (long) (*(short *) arg_scalar);
      break;
#if (INTSIZE > SHORTSIZE) && (INTSIZE < LONGSIZE)
    case INTSIZE:
      *lptr = (long) (*(int *) arg_scalar);
      break;
#endif
#if LONGSIZE > SHORTSIZE
    case LONGSIZE:
      *lptr = *(long *) arg_scalar;
      break;
#endif
    default:
      croak("Argument %d has unsupported length %d bytes.",
	    i + 1 - DYNALIB_ARGSTART, (int) arg_scalar);
    }
  }
#ifdef __GNUC__
  /* If any of the first six args are type double, the calling
     convention is to place them in floating point registers.  We don't
     know if they're doubles or not (well, we /could/ find out...)
     so we play it safe by filling the fp regs with what they would
     contain if the args were doubles.

     I don't know how to do inline assembly with other compilers.
     */
  asm("ldt $f16, %0" : : "m"(pseu[0]));
  asm("ldt $f17, %0" : : "m"(pseu[1]));
  asm("ldt $f18, %0" : : "m"(pseu[2]));
  asm("ldt $f19, %0" : : "m"(pseu[3]));
  asm("ldt $f20, %0" : : "m"(pseu[4]));
  asm("ldt $f21, %0" : : "m"(pseu[5]));
#endif
  /* Cross your fingers. */
  return (*((long (*)()) func))(pseu[0], pseu[1], pseu[2],
				pseu[3], pseu[4], pseu[5]);
}

#define alpha_CALL(func, type)						\
    ((*((type (*)(I32, I32, void *)) alpha_pray))(ax,items,func))
