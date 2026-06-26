# ===================================================================
# Makefile — top-level entrypoint
#
# Actual targets live in phase-crossregion/Makefile (the only active
# phase with a Makefile right now). Other phases (phase-base / phase-k8s
# / phase-threadcontrol) currently invoke ansible / scripts directly,
# no Makefile.
#
# Operator commands stay unchanged:
#   make help
#   make phase-crossregion-all
#   make phase6-tidb-smoke
#   ... etc.
#
# Historical: Makefile.tc1 is the legacy vm-1node Makefile (pre-fork);
# kept for reference, not included.
# ===================================================================

include phase-crossregion/Makefile
