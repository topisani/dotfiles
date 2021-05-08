/* See LICENSE file for copyright and license details. */

#include "util.h"
#include "ewmh.hpp"

template<typename T>
T* malloc_var(T*& var, unsigned n = 1) {
  return var = static_cast<T*>(malloc(sizeof(T) * n));
}

static void usage(char *name) {
  fprintf(stderr, "usage: %s <wid>\n", name);
  exit(1);
}

int get_type(xcb_window_t win) {
  xcb_get_property_cookie_t c_type;
  xcb_ewmh_get_atoms_reply_t* r_type;
  int status;

  malloc_var(r_type);

  /* _NET_WM_WINDOW_TYPE */
  c_type = xcb_ewmh_get_wm_window_type(ewmh, win);
  status = xcb_ewmh_get_wm_window_type_reply(ewmh, c_type, r_type, NULL);
  if (status == 1) {
    printf("%s\n", window_type_to_string(r_type));
    return 0;
  } else {
    return 1;
  }

  free(r_type);
}

int main(int argc, char **argv) {
  int i, r = 0;

  if (argc < 2)
    usage(argv[0]);

  init_xcb(&conn);
  init_ewmh();

  for (i = 1; i < argc; i++)
    r += get_type(strtoul(argv[i], NULL, 16));

  kill_xcb(&conn);

  return r;
}
