using TestItemRunner

# Exclude the interop cross-test group from the main test env.
# Interop items live in test/interop/ and require Nghttp2Wrapper.jl,
# which is only available in the separate test/interop/ environment
# (Julia ≥ 1.12). They are run via
#   julia --project=test/interop test/interop/runtests.jl
# from CI and from local reproduction.
@run_package_tests filter = ti -> !startswith(ti.name, "Interop: ")
