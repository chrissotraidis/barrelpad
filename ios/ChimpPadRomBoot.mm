#include "ChimpPadRomBoot.h"

#import <Foundation/Foundation.h>
#include <TargetConditionals.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char sResolvedRom[1024];

const char *ChimpPad_ResolvedRomPath(void) {
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

int ChimpPad_PrepareIosRomBoot(void) {
    sResolvedRom[0] = '\0';

    const char *existing = getenv("MDKR_ROM");
    if (existing != NULL && existing[0] != '\0') {
        snprintf(sResolvedRom, sizeof(sResolvedRom), "%s", existing);
        if (getenv("MDKR_APP_AUTOPLAY") == NULL) {
            setenv("MDKR_APP_AUTOPLAY", "1", 1);
            fprintf(stderr,
                    "[ChimpPad] MDKR_ROM present; enabling MDKR_APP_AUTOPLAY "
                    "for game boot with touch\n");
        }
        fprintf(stderr, "[ChimpPad] using MDKR_ROM=%s\n", sResolvedRom);
        return 1;
    }

    NSArray<NSString *> *docs = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES);
    if (docs.count == 0) {
        fprintf(stderr, "[ChimpPad] Documents directory unavailable\n");
        return 0;
    }
    NSString *picked = pickRomInDirectory(docs.firstObject);
    if (picked == nil) {
        /* Also check a nested ROMs folder if present. */
        NSString *nested =
            [docs.firstObject stringByAppendingPathComponent:@"ROMs"];
        picked = pickRomInDirectory(nested);
    }
    if (picked == nil) {
        fprintf(stderr,
                "[ChimpPad] no ROM in Documents — launcher will ask for one\n");
        return 0;
    }

    snprintf(sResolvedRom, sizeof(sResolvedRom), "%s", picked.UTF8String);
    setenv("MDKR_ROM", sResolvedRom, 1);
    if (getenv("MDKR_APP_AUTOPLAY") == NULL) {
        setenv("MDKR_APP_AUTOPLAY", "1", 1);
    }
    fprintf(stderr,
            "[ChimpPad] Documents ROM selected: %s (autoplay on)\n",
            sResolvedRom);
    return 1;
}

#else

int ChimpPad_PrepareIosRomBoot(void) {
    sResolvedRom[0] = '\0';
    return 0;
}

#endif
