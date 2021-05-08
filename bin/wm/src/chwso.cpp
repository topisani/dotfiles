/* See LICENSE file for copyright and license details. */

#include <vector>
#include <algorithm>
#include "ewmh.hpp"
#include <xcb/xcb_aux.h>

uint32_t raise_vals[1] = {XCB_STACK_MODE_ABOVE};
uint32_t lower_vals[1] = {XCB_STACK_MODE_BELOW};
uint32_t invert_vals[1] = {XCB_STACK_MODE_OPPOSITE};

template<typename T>
T* malloc_var(T*& var, unsigned n = 1) {
  return var = static_cast<T*>(malloc(sizeof(T) * n));
}

void usage(char *name) {
  fprintf(stderr, "usage: %s -rli <wid> [wid]...\n", name);
  exit(1);
}

void stack(xcb_window_t win, uint32_t values[1]) {
  xcb_configure_window(conn, win, XCB_CONFIG_WINDOW_STACK_MODE, values);
}

int window_order(xcb_window_t win) {
  xcb_get_property_cookie_t c_type;
  xcb_ewmh_get_atoms_reply_t* r_type;
  int status;

  malloc_var(r_type);

  /* _NET_WM_WINDOW_TYPE */
  c_type = xcb_ewmh_get_wm_window_type(ewmh, win);
  status = xcb_ewmh_get_wm_window_type_reply(ewmh, c_type, r_type, NULL);

  int const noorder = std::numeric_limits<int>::min();
  int order = noorder;

  if (status == 1 && r_type->atoms != nullptr) {
    for (int i = 0; i < r_type->atoms_len; i++) {
      xcb_atom_t a = r_type->atoms[i];
#define WT_STRING(type, o)                                              \
      if (a == ewmh->_NET_WM_WINDOW_TYPE_##type)                        \
        order = std::max(order, o);
      WT_STRING(DESKTOP, -1)
        WT_STRING(DOCK, 2)
        WT_STRING(TOOLBAR, 2)
        WT_STRING(MENU, 5)
        WT_STRING(UTILITY, noorder)
        WT_STRING(SPLASH, 2)
        WT_STRING(DIALOG, 0)
        WT_STRING(DROPDOWN_MENU, 5)
        WT_STRING(POPUP_MENU, 5)
        WT_STRING(TOOLTIP, 6)
        WT_STRING(NOTIFICATION, 3)
        WT_STRING(COMBO, noorder)
        WT_STRING(DND, 6)
        WT_STRING(NORMAL, 0)
#undef WT_STRING
        }
  } else {
    order = 0;
  }

  free(r_type);

  return order;
}

std::vector<xcb_window_t> windows;

void get_stack() {

  int i, wn;
  xcb_window_t *wc;
  wn = get_windows(conn, scrn->root, &wc);

  if (wc == NULL)
    errx(1, "0x%08x: unable to retrieve children", scrn->root);

  windows.reserve(wn);
  std::copy_n(wc, wn, std::back_inserter(windows));

}

void apply_stack() {

  std::stable_sort(windows.begin(), windows.end(),
    [] (auto w1, auto w2) {
      return window_order(w1) < window_order(w2);
    });

  for (auto win : windows) {
    stack(win, raise_vals);
  }
}

int main(int argc, char **argv) {
  xcb_window_t win;

  if (argc < 3)
    usage(argv[0]);

  init_xcb(&conn);
  init_ewmh();
  get_screen(conn, &scrn);

  int action = 0;

  ARGBEGIN {
  case 'r':
    action = 0;
    break;
  case 'l':
    action = 1;
    break;
  case 'i':
    action = 2;
    break;
  default:
    usage(nullptr);
    break;
  }
  ARGEND;

  if (action == 2) {
    for (int i = 2; i < argc; i++) {
      win = strtoul(argv[1], NULL, 16);
      if (!win)
        continue;
      stack(win, invert_vals);
    }
    get_stack();
  } else {
    get_stack();
    for (int i = 2; i < argc; i++) {
      win = strtoul(argv[1], NULL, 16);
      if (!win)
        continue;
      windows.erase(std::remove(windows.begin(), windows.end(), win));
      if (action == 0) {
        windows.push_back(win);
      } else {
        windows.insert(windows.begin(), win);
      }
    }
  }

  apply_stack();
  xcb_aux_sync(conn);

  kill_xcb(&conn);

  return 0;
}
