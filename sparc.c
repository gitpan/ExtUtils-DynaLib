#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif

static int sparc_pray(void *func) {
  dXSARGS;
  STRLEN arg_len;
  char *arg_scalar, *arg_on_stack;
  int nbytes = 0;
  int pseu[6];  /* Array of first six "pseudo-arguments" */
  int check_len;
  register int i = 1, j;
  int stack_needed = 0;

  while (i < items) {
    arg_scalar = SvPV(ST(i), arg_len);
    i++;
    check_len = nbytes + arg_len;
    if (check_len > sizeof pseu) {
      stack_needed = check_len - sizeof pseu;
      arg_len -= stack_needed;
    }
    Copy(arg_scalar, &((char *) (&pseu[0]))[nbytes], arg_len, char);
    nbytes = check_len;
    if (check_len >= sizeof pseu) {
      for (j = i; j < items; j++) {
	SvPV(ST(j), arg_len);
	stack_needed += arg_len;
      }
      if (stack_needed > 0) {
	/* Wish I knew why we have to subtract off 4. */
	arg_on_stack = alloca(stack_needed) - sizeof (int);
	if (check_len > sizeof pseu) {
	  arg_len = check_len - sizeof pseu;
	  Copy(&arg_scalar[arg_len], arg_on_stack, arg_len, char);
	  arg_on_stack += arg_len;
	}
	while (i < items) {
	  arg_scalar = SvPV(ST(i), arg_len);
	  i++;
	  Copy(arg_scalar, arg_on_stack, arg_len, char);
	  arg_on_stack += arg_len;
	}
      }
    }
  }
  /* Cross your fingers. */
  return (*((int (*)()) func))(pseu[0], pseu[1], pseu[2],
			       pseu[3], pseu[4], pseu[5]);
}

#define sparc_CALL(func, type) ((*((type (*)(void *)) sparc_pray))(func))
