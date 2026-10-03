# Validation scope

The preserved upmix block was compared bit for bit with an independent v3
reference in fifteen scenarios: 11,520,000 output floats across ten channels.
Seven software suites passed for transport, DSP, calibration, interprocess IPC,
production plugin callbacks, engine policies and installation preconditions.
No audio source changed during release staging, so those DSP tests were not
repeated for packaging.

Twelve real Windows PowerShell 5.1 CLI cases passed: valid modes tolerate quotes
and whitespace; unknown/extra modes fail before data creation. Mapping reopen
preserves existing bytes and rejects an invalid header without overwriting it.
The .NET null-string compatibility fixes were verified in isolated owned files.

An integrated installation test connected capture and validated the ten-object
route. Input and spatial delivery counters advanced without the reported
conflict/invalid-sample/overflow flags. The tester explicitly confirmed hearing
surround and height output. These observations come from one hardware setup;
no personal endpoint identity, raw PCM or local runtime log is distributed.

The whole chain's gain, latency, individual loudspeaker response, authored
object metadata reconstruction, prolonged-silence keepalive and behavior after
all suspend/disconnect/reload conditions were not established by these tests.
The source-level DSP equivalence and the integrated listening confirmation are
separate evidence classes.

Lifecycle installation, changed-binary upgrade, removal and reinstallation
are exercised with real files in an isolated fixture, with operating-system
and audio operations replaced by explicit test hooks. UTF-8, UTF-8 BOM and
UTF-16 LE/BE configurations restore byte for byte. External edits and unknown
files are preserved. Modified blocks, wrong owners, adulterated backups and
unrecognized roots are refused. A failing prepare step leaves the original
configuration unattached and its backup preserved. The final assertion count
and source checksums are recorded in release-manifest.json.

The x64 native setup compiled successfully. Its embedded manifest declares
asInvoker. Only its hash-checked worker requests elevation. Uninstall launches
a verified temporary copy and exits the installed parent so the original setup
can be removed. Concurrent lifecycle actions are rejected by a global mutex.
The production setup UI, UAC, shortcuts/registry registration and loaded-DLL
uninstall have not been executed by these isolated fixture tests.
