#pragma once

#include <stddef.h>
#include <stdint.h>

enum {
    BARRELPAD_CONTROLLER_SLOT_COUNT = 4,
    BARRELPAD_CONTROLLER_ID_NONE = -1
};

typedef struct BarrelPadControllerSlots {
    int32_t instanceIds[BARRELPAD_CONTROLLER_SLOT_COUNT];
} BarrelPadControllerSlots;

typedef struct BarrelPadControllerSlotChanges {
    uint8_t releasedMask;
    uint8_t assignedMask;
} BarrelPadControllerSlotChanges;

static inline void BarrelPad_ControllerSlotsInit(BarrelPadControllerSlots *slots) {
    if (slots == NULL) {
        return;
    }
    for (int i = 0; i < BARRELPAD_CONTROLLER_SLOT_COUNT; ++i) {
        slots->instanceIds[i] = BARRELPAD_CONTROLLER_ID_NONE;
    }
}

static inline int BarrelPad_ControllerSlotForInstance(
    const BarrelPadControllerSlots *slots, int32_t instanceId) {
    if (slots == NULL || instanceId < 0) {
        return -1;
    }
    for (int i = 0; i < BARRELPAD_CONTROLLER_SLOT_COUNT; ++i) {
        if (slots->instanceIds[i] == instanceId) {
            return i;
        }
    }
    return -1;
}

static inline int BarrelPad_ControllerInstanceIsCurrent(
    int32_t instanceId, const int32_t *currentInstanceIds, size_t currentCount) {
    if (instanceId < 0 || currentInstanceIds == NULL) {
        return 0;
    }
    for (size_t i = 0; i < currentCount; ++i) {
        if (currentInstanceIds[i] == instanceId) {
            return 1;
        }
    }
    return 0;
}

/* Preserve current owners, release identities no longer enumerated by SDL,
 * then assign new identities to the lowest available player slot. */
static inline BarrelPadControllerSlotChanges BarrelPad_ControllerSlotsReconcile(
    BarrelPadControllerSlots *slots,
    const int32_t *currentInstanceIds,
    size_t currentCount) {
    BarrelPadControllerSlotChanges changes = {0, 0};
    if (slots == NULL) {
        return changes;
    }

    for (int slot = 0; slot < BARRELPAD_CONTROLLER_SLOT_COUNT; ++slot) {
        const int32_t instanceId = slots->instanceIds[slot];
        if (instanceId != BARRELPAD_CONTROLLER_ID_NONE &&
            !BarrelPad_ControllerInstanceIsCurrent(
                instanceId, currentInstanceIds, currentCount)) {
            slots->instanceIds[slot] = BARRELPAD_CONTROLLER_ID_NONE;
            changes.releasedMask |= (uint8_t)(1u << slot);
        }
    }

    for (size_t i = 0; i < currentCount; ++i) {
        const int32_t instanceId = currentInstanceIds[i];
        if (instanceId < 0 ||
            BarrelPad_ControllerSlotForInstance(slots, instanceId) >= 0) {
            continue;
        }
        for (int slot = 0; slot < BARRELPAD_CONTROLLER_SLOT_COUNT; ++slot) {
            if (slots->instanceIds[slot] == BARRELPAD_CONTROLLER_ID_NONE) {
                slots->instanceIds[slot] = instanceId;
                changes.assignedMask |= (uint8_t)(1u << slot);
                break;
            }
        }
    }
    return changes;
}
