#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Starts one process-wide, private, bounded stderr capture. Stored text is
// sanitized line-by-line before it reaches Application Support.
void dinopad_start_diagnostics_log(void);

// Marks this process as having reached a normal exit boundary.
void dinopad_finish_diagnostics_log(void);

// Builds a bounded redacted report, presents the native share sheet, removes
// the temporary report after dismissal, then invokes completion.
void dinopad_present_diagnostics_share(void* presenter_pointer,
                                        void (^completion)(void));

#ifdef __cplusplus
}
#endif
