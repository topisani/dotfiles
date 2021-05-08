/* See LICENSE file for copyright and license details. */

#include "util.h"
#include "ewmh.hpp"

static void usage(char *);
static int get_title(xcb_window_t);

static void usage(char *name) {
  fprintf(stderr, "usage: %s <wid>\n", name);
  exit(1);
}

static int get_title(xcb_window_t win) {
  char* name;
  /* WM_NAME */
  name = get_string_prop(win, ewmh->_NET_WM_NAME, 1);
  if (name[0] == '\0') {
    free(name);
    name = get_string_prop(win, get_atom("WM_NAME"), 0);
  }

  if (name[0] == '\0') {
    warnx("could not get window title");
    return 1;
  }
  printf("%s\n", name);
  return 0;

}

int main(int argc, char **argv) {
  int i, r = 0;

  if (argc < 2)
    usage(argv[0]);

  init_xcb(&conn);
  init_ewmh();

  for (i = 1; i < argc; i++)
    r += get_title(strtoul(argv[i], NULL, 16));

  kill_xcb(&conn);

  return r;
}
