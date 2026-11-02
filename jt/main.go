// jt is a task tracker built on jj changes. See `jt --help`.
//
// A task is any change whose description ends with a trailer block containing
// `Task-Status:`. The change id is the task id. Blockers are parent edges. There
// is no other state: the board is `jj log`.
package main

import (
	"errors"
	"fmt"
	"os"

	"jt/internal/core"
)

// exitError carries a specific exit code with an already-printed message.
type exitError struct{ code int }

func (e exitError) Error() string { return fmt.Sprintf("exit %d", e.code) }

func main() {
	if err := rootCmd().Execute(); err != nil {
		var ee exitError
		if errors.As(err, &ee) {
			os.Exit(ee.code)
		}
		var vf *core.VerifyFailed
		if errors.As(err, &vf) {
			printVerify(&vf.Report)
			os.Exit(1)
		}
		fmt.Fprintf(os.Stderr, "jt: %v\n", err)
		os.Exit(1)
	}
}
