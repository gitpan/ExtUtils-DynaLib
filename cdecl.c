#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif

static int
cdecl_pray(ax, items, func)
I32 ax;
I32 items;
void *func;
{
  STRLEN arg_len;
  void *arg_scalar, *arg_on_stack;
  register int i;

  /* Place C arguments on stack backwards--it's the convention. */
  for (i = items; i-- > 1; ) {
    arg_scalar = SvPV(ST(i), arg_len);
    arg_on_stack = alloca(arg_len);
    Copy(arg_scalar, arg_on_stack, arg_len, char);
  }
  /* Cross your fingers. */
  return (*((int (*)()) func))();
}

#define cdecl_CALL(func, type)						\
    ((*((type (*)(I32, I32, void *)) cdecl_pray))(ax,items,func))
