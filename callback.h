typedef int (*cb_callback) _((int a, ...));
typedef struct {
  SV *coderef;
  char *ret_type;
  char *arg_type;
  cb_callback func;
} cb_entry;

static int cb_call_sub _((int index, int first, va_list ap));
