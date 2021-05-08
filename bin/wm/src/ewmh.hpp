#pragma once

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/select.h>
#include <sys/wait.h>
#include <xcb/xcb.h>
#include <xcb/xcb_ewmh.h>
#include <xcb/xcb_icccm.h>

#include "arg.h"
#include "util.h"

enum { ATOM_WM_NAME, ATOM_WM_CLASS, ATOM_WM_ROLE, ATOM_WM_TYPE, NR_ATOMS };

static const char *atom_names[] = {"WM_NAME", "WM_CLASS", "WM_WINDOW_ROLE",
                                   "_NET_WM_WINDOW_TYPE"};

xcb_connection_t *conn;
xcb_screen_t *scrn;
xcb_ewmh_connection_t *ewmh;

xcb_atom_t allowed_atoms[NR_ATOMS];

char *strip_quotes(char *str) {
  /* length of original string - 2 (two quotes) + 1 (a null terminator) */
  int len = strlen(str) - 2;

  /* check if string needs to be stripped */
  if (str[0] != '"' || str[len + 1] != '"')
    return str;

  char *s = (char*) malloc((len + 1) * sizeof(char));
  int i;

  for (i = 1; i < strlen(str) - 1; i++) {
    s[i - 1] = str[i];
  }
  s[len] = '\0';
  free(str);

  return s;
}

/*
 * Init ewmh connection.
 */
void init_ewmh(void) {
  ewmh = (xcb_ewmh_connection_t*) malloc(sizeof(xcb_ewmh_connection_t));
  if (!ewmh)
    warnx("couldn't set up ewmh connection");
  xcb_ewmh_init_atoms_replies(ewmh, xcb_ewmh_init_atoms(conn, ewmh), NULL);
}

/*
 * Get atom by name.
 */
xcb_atom_t get_atom(const char *name) {
  xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(
      conn, xcb_intern_atom(conn, 0, strlen(name), name), NULL);
  xcb_atom_t atom;

  if (!r) {
    warnx("couldn't get atom '%s'\n", name);
    return XCB_ATOM_STRING;
  }
  atom = r->atom;
  free(r);

  return atom;
}

/*
 * Populate the list of allowed atoms.
 */
void populate_allowed_atoms(void) {
  int i;

  for (i = 0; i < NR_ATOMS; i++) {
    allowed_atoms[i] = get_atom(atom_names[i]);
  }
}

/*
 * Get string property of window by atom.
 */
char *get_string_prop(xcb_window_t win, xcb_atom_t prop, int utf8) {
  char *p, *value;
  int len = 0;
  xcb_get_property_cookie_t c;
  xcb_get_property_reply_t *r = NULL;
  xcb_atom_t type;

  if (utf8)
    type = ewmh->UTF8_STRING;
  else
    type = XCB_ATOM_STRING;

  c = xcb_get_property(conn, 0, win, prop, type, 0L, 4294967295L);
  r = xcb_get_property_reply(conn, c, NULL);

  if (r == NULL || xcb_get_property_value_length(r) == 0) {
    p = strdup("");
    warnx("unable to get window property for 0x%08x\n", win);
  } else {
    len = xcb_get_property_value_length(r);
    p = (char *)malloc((len + 1) * sizeof(char));
    value = (char *)xcb_get_property_value(r);
    strncpy(p, value, len);
    p[len] = '\0';
  }
  free(r);

  return p;
}

#define WINDOW_TYPE_STRING_LENGTH 110

/*
 * Convert window type atom to string form.
 */
char *window_type_to_string(xcb_ewmh_get_atoms_reply_t *reply) {
  int i;
  char *atom_name = NULL;
  char *str;

  if (reply != NULL) {
    str = (char*) malloc((WINDOW_TYPE_STRING_LENGTH + 1) * sizeof(char));
    str[0] = '\0';
    for (i = 0; i < reply->atoms_len; i++) {
      xcb_atom_t a = reply->atoms[i];
#define WT_STRING(type, s)                                                     \
  if (a == ewmh->_NET_WM_WINDOW_TYPE_##type)                                   \
    atom_name = strdup(#s);
      WT_STRING(DESKTOP, desktop)
      WT_STRING(DOCK, dock)
      WT_STRING(TOOLBAR, toolbar)
      WT_STRING(MENU, menu)
      WT_STRING(UTILITY, utility)
      WT_STRING(SPLASH, splash)
      WT_STRING(DIALOG, dialog)
      WT_STRING(DROPDOWN_MENU, dropdown_menu)
      WT_STRING(POPUP_MENU, popup_menu)
      WT_STRING(TOOLTIP, tooltip)
      WT_STRING(NOTIFICATION, notification)
      WT_STRING(COMBO, combo)
      WT_STRING(DND, dnd)
      WT_STRING(NORMAL, normal)
#undef WT_STRING

      if (atom_name != NULL) {
        if (i == 0)
          sprintf(str, "%s", atom_name);
        else
          sprintf(str, "%s,%s", str, atom_name);
      }

      free(atom_name);
      atom_name = NULL;
    }
  } else {
    str = strdup("");
  }

  return str;
}
