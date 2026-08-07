# Extend Golden Balloon wgpu selection for iOS Simulator / device.
# Include from BarrelPad iOS configure after copying into the host tree, or
# set MDKR_WGPU_* overrides before including stock webgpu.cmake.

function(barrelpad_select_wgpu_ios cpu simulator out_supported out_asset out_sha out_reason)
    string(TOLOWER "${cpu}" _cpu)
    set(_supported TRUE)
    set(_asset "")
    set(_sha "")
    set(_reason "")

    if(simulator)
        if(_cpu MATCHES "^(arm64|aarch64)$")
            set(_asset "wgpu-ios-aarch64-simulator-release.zip")
            set(_sha "750e706765bef3744313745194774d095c916fc21d2a0e7d4d7b0bc4d0c92789")
        elseif(_cpu MATCHES "^(x86_64|amd64)$")
            set(_asset "wgpu-ios-x86_64-simulator-release.zip")
            # Hash filled when used; prefer arm64 Simulator on Apple silicon.
            set(_supported FALSE)
            set(_reason "x86_64 iOS Simulator wgpu not pinned; use arm64")
        else()
            set(_supported FALSE)
        endif()
    else()
        if(_cpu MATCHES "^(arm64|aarch64)$")
            set(_asset "wgpu-ios-aarch64-release.zip")
            # Device hash not pinned in this milestone; fail closed unless set.
            set(_supported FALSE)
            set(_reason "device iOS wgpu pin deferred; Simulator-only for now")
        else()
            set(_supported FALSE)
        endif()
    endif()

    if(NOT _supported AND _reason STREQUAL "")
        set(_reason "no pinned wgpu-native for iOS cpu=${cpu} simulator=${simulator}")
    endif()

    set(${out_supported} "${_supported}" PARENT_SCOPE)
    set(${out_asset} "${_asset}" PARENT_SCOPE)
    set(${out_sha} "${_sha}" PARENT_SCOPE)
    set(${out_reason} "${_reason}" PARENT_SCOPE)
endfunction()
