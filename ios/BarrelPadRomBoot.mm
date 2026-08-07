#include "BarrelPadRomBoot.h"

#import <Foundation/Foundation.h>
#include <TargetConditionals.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char sResolvedRom[1024];

const char *BarrelPad_ResolvedRomPath(void) {
    return sResolvedRom[0] ? sResolvedRom : NULL;
}

#if TARGET_OS_IOS

static int pathLooksLikeRom(NSString *name) {
    NSString *lower = name.lowercaseString;
    return [lower hasSuffix:@".v64"] || [lower hasSuffix:@".z64"] ||
           [lower hasSuffix:@".n64"];
}

static NSString *pickRomInDirectory(NSString *dir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString *> *names =
        [fm contentsOfDirectoryAtPath:dir error:nil];
    if (names.count == 0) {
        return nil;
    }
    /* Prefer the canonical name used by scripts/run-ios-sim.sh */
    for (NSString *n in names) {
        if ([n.lowercaseString isEqualToString:@"diddy-kong-racing.v64"] ||
            [n.lowercaseString isEqualToString:@"diddy-kong-racing.z64"]) {
            return [dir stringByAppendingPathComponent:n];
        }
    }
    for (NSString *n in names) {
        if (pathLooksLikeRom(n)) {
            return [dir stringByAppendingPathComponent:n];
        }
    }
    return nil;
}

/*
 * CoreDevice treats a single-file copy whose destination is "Documents" as
 * a replacement for the directory rather than a copy into it. Repair that
 * malformed state once, keeping the transferred ROM and restoring the normal
 * Files-visible Documents directory before the engine resolves its paths.
 */
static NSString *prepareDocumentsDirectory(void) {
    NSArray<NSString *> *docs = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES);
    if (docs.count == 0) {
        return nil;
    }

    NSString *docsPath = docs.firstObject;
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:docsPath isDirectory:&isDirectory] || isDirectory) {
        return docsPath;
    }

    NSString *holdingPath = [docsPath stringByAppendingString:@".barrelpad-recovery"];
    NSError *error = nil;
    if ([fm fileExistsAtPath:holdingPath] ||
        ![fm moveItemAtPath:docsPath toPath:holdingPath error:&error]) {
        fprintf(stderr, "[BarrelPad] could not recover malformed Documents path: %s\n",
                error.localizedDescription.UTF8String);
        return nil;
    }
    if (![fm createDirectoryAtPath:docsPath
       withIntermediateDirectories:NO attributes:nil error:&error]) {
        fprintf(stderr, "[BarrelPad] could not recreate Documents: %s\n",
                error.localizedDescription.UTF8String);
        [fm moveItemAtPath:holdingPath toPath:docsPath error:nil];
        return nil;
    }

    NSString *romPath = [docsPath stringByAppendingPathComponent:@"diddy-kong-racing.v64"];
    if ([fm fileExistsAtPath:romPath]) {
        romPath = [docsPath stringByAppendingPathComponent:@"diddy-kong-racing-recovered.v64"];
    }
    if (![fm moveItemAtPath:holdingPath toPath:romPath error:&error]) {
        fprintf(stderr, "[BarrelPad] Documents recovered but ROM is held at %s: %s\n",
                holdingPath.UTF8String, error.localizedDescription.UTF8String);
        return docsPath;
    }
    fprintf(stderr, "[BarrelPad] recovered ROM into Documents: %s\n", romPath.UTF8String);
    return docsPath;
}

int BarrelPad_PrepareIosRomBoot(void) {
    sResolvedRom[0] = '\0';

    /* A UIKit game has no useful windowed mode. Resolve the host window before
     * AppHost creates SDL so the Metal drawable uses the complete iPhone/iPad
     * landscape surface. Keep the game's native Hor+ presentation enabled. */
    setenv("MDKR_WINDOW_MODE", "fullscreen", 1);
    setenv("MDKR_WIDESCREEN", "1", 1);
    setenv("MDKR_ASPECT", "auto", 1);

    /* Point every writable engine/launcher path at the app's own Documents so
     * settings, video config, and saves work inside the sandbox. SDL_GetPrefPath
     * cannot resolve on iOS (no $HOME), and the engine's packaged-path marker is
     * macOS-only (.app/Contents/MacOS/), so without these the device falls back
     * to CWD=/, which is not writable ("settings file is not writable"). */
    NSString *docsPath = prepareDocumentsDirectory();
    if (docsPath != nil) {
        setenv("MDKR_APP_PREFS_DIR", docsPath.UTF8String, 1);
        setenv("MDKR_VIDEO_CONFIG_PATH",
               [docsPath stringByAppendingPathComponent:@"mdkr64.ini"].UTF8String, 1);
        setenv("MDKR_SAVE_DIR",
               [docsPath stringByAppendingPathComponent:@"save"].UTF8String, 1);
        fprintf(stderr, "[BarrelPad] writable dirs -> %s\n", docsPath.UTF8String);
    }

    const char *existing = getenv("MDKR_ROM");
    if (existing != NULL && existing[0] != '\0') {
        snprintf(sResolvedRom, sizeof(sResolvedRom), "%s", existing);
        if (getenv("MDKR_APP_AUTOPLAY") == NULL) {
            setenv("MDKR_APP_AUTOPLAY", "1", 1);
            fprintf(stderr,
                    "[BarrelPad] MDKR_ROM present; enabling MDKR_APP_AUTOPLAY "
                    "for game boot with touch\n");
        }
        fprintf(stderr, "[BarrelPad] using MDKR_ROM=%s\n", sResolvedRom);
        return 1;
    }

    if (docsPath == nil) {
        fprintf(stderr, "[BarrelPad] Documents directory unavailable\n");
        return 0;
    }
    NSString *picked = pickRomInDirectory(docsPath);
    if (picked == nil) {
        /* Also check a nested ROMs folder if present. */
        NSString *nested =
            [docsPath stringByAppendingPathComponent:@"ROMs"];
        picked = pickRomInDirectory(nested);
    }
    if (picked == nil) {
        fprintf(stderr,
                "[BarrelPad] no ROM in Documents — launcher will ask for one\n");
        return 0;
    }

    snprintf(sResolvedRom, sizeof(sResolvedRom), "%s", picked.UTF8String);
    setenv("MDKR_ROM", sResolvedRom, 1);
    if (getenv("MDKR_APP_AUTOPLAY") == NULL) {
        setenv("MDKR_APP_AUTOPLAY", "1", 1);
    }
    fprintf(stderr,
            "[BarrelPad] Documents ROM selected: %s (autoplay on)\n",
            sResolvedRom);
    return 1;
}

#else

int BarrelPad_PrepareIosRomBoot(void) {
    sResolvedRom[0] = '\0';
    return 0;
}

#endif
