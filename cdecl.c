#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif

#ifdef __BORLANDC__
#include <malloc.h>
#endif  /* __BORLANDC__ */

static int
cdecl_pray(ax, items, func)
I32 ax;
I32 items;
void *func;
{
  STRLEN arg_len;
  char *arg_scalar, *arg_on_stack;
  register int i;
#ifdef CDECL_ONE_BY_ONE

  /* Place C arguments on stack backwards--it's the convention. */
  for (i = items; i-- > 1; ) {
    arg_scalar = SvPV(ST(i), arg_len);
    arg_on_stack = alloca(arg_len);
    Copy(arg_scalar, arg_on_stack, arg_len, char);
  }
#else  /* ! CDECL_ONE_BY_ONE */
  STRLEN total_arg_len = 0;

  for (i = items; i-- > 1; ) {
    (void) SvPV(ST(i), arg_len);
    total_arg_len += arg_len;
  }
  arg_on_stack = alloca(total_arg_len);
#ifdef CDECL_SUBTRACT_CURRENT
  arg_on_stack -= (sizeof ax + sizeof items + sizeof func);
#endif  /* CDECL_SUBTRACT_CURRENT */
  for (i = 1; i < items; i++) {
    arg_scalar = SvPV(ST(i), arg_len);
    Copy(arg_scalar, arg_on_stack, arg_len, char);
    arg_on_stack += arg_len;
  }
#endif  /* ! CDECL_ONE_BY_ONE */

  /* Cross your fingers. */
  return (*((int (*)()) func))();
}

#define cdecl_CALL(func, type)						\
    ((*((type (*)(I32, I32, void *)) cdecl_pray))(ax,items,func))
