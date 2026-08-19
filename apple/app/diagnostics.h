#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Starts one process-wide, private, bounded stderr capture. Stored text is
// sanitized line-by-line before it reaches Application Support.
void dinopad_start_diagnostics_log(void);

// Marks this process as having reached a normal exit boundary.
void dinopad_finish_diagnostics_log(void);

// Writes a compact timestamped lifecycle/input breadcrumb to the private
// runtime log. Callers must pass fixed, non-user-authored strings.
void dinopad_diagnostics_breadcrumb(const char* category, const char* event);

// Marks the recompiled runtime boundary and feeds its low-overhead progress
// watchdog. A suspected stall is logged only while the app is active.
void dinopad_diagnostics_set_runtime_active(int active);
void dinopad_diagnostics_gameplay_poll(void);

// Builds a bounded redacted report, presents the native share sheet, removes
// the temporary report after dismissal, then invokes completion.
void dinopad_present_diagnostics_share(void* presenter_pointer,
                                        void (^completion)(void));

#ifdef __cplusplus
}
#endif
