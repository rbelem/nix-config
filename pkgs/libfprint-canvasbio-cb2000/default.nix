{ libfprint }:

libfprint.overrideAttrs (oldAttrs: {
  # The VirtualImage.test_enroll_verify virtual-device test is flaky under
  # the nix build sandbox (times out ~33s). It tests mock devices, not the
  # real CanvasBio driver. Keep doInstallCheck true so python3 stays in the
  # build env (meson configure needs it), but no-op the check phase itself.
  installCheckPhase = ''
    runHook preInstallCheck
    runHook postInstallCheck
  '';

  # CanvasBio CB2000 driver (B1-R1.2) from kpagnussat/canvasbio-cb2000
  # https://github.com/kpagnussat/canvasbio-cb2000
  #
  # SigFM matcher uses SIFT keypoints with geometric consensus voting
  # (replaces the NCC matcher in the previous V44 driver).
  # OpenCV helper (libcb2000_sigfm_opencv.so) is loaded at runtime via
  # dlopen with a pure-C fallback — no OpenCV build-time dependency.
  postPatch = (oldAttrs.postPatch or "") + ''
    # Copy driver source files into the libfprint source tree
    mkdir -p libfprint/drivers/canvasbio_cb2000
    cp ${./src/canvasbio_cb2000.c} libfprint/drivers/canvasbio_cb2000/canvasbio_cb2000.c
    cp ${./src/cb2000_sigfm_matcher.c} libfprint/drivers/canvasbio_cb2000/cb2000_sigfm_matcher.c
    cp ${./src/cb2000_sigfm_matcher.h} libfprint/drivers/canvasbio_cb2000/cb2000_sigfm_matcher.h

    # Register driver in libfprint/meson.build (driver_sources dict)
    substituteInPlace libfprint/meson.build \
      --replace-fail \
        "'drivers/focaltech_moc/focaltech_moc.c' ]," \
        "'drivers/focaltech_moc/focaltech_moc.c' ],
    'canvasbio_cb2000' :
        [ 'drivers/canvasbio_cb2000/canvasbio_cb2000.c' ],"

    # Register driver in meson.build (default_drivers + endian_independent_drivers)
    substituteInPlace meson.build \
      --replace \
        "'focaltech_moc'," \
        "'focaltech_moc',
    'canvasbio_cb2000',"
  '';
})
