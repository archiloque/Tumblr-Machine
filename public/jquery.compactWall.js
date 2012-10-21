/**
 * jQuery CompactWall v0.2.0
 * A jQuery plugin to organizes blocks in a compact way.
 * http://github.com/archiloque/compact-wall
 *
 * Licensed under the MIT license.
 * Copyright 2012 Julien Kirch
 */

(function ($) {
    $.fn.compactWall = function (blocks, options) {

        // the algorithm works by placing the blocks
        // from the biggest to the smallest in the possible positions
        // therefore it doesn't provide the best position
        // but a good enough one without requiring too much calculations

        // the code is kept simple, the only trick is
        // some optimizations when several blocks have the same size
        // to avoid recalculating the same positions several times
        // for this we keep a list of all the already used positions for a group
        // when dealing with groups, the position of a block is
        // the height * containerWidth + width

        // a slot represents a position where a block can be placed, it contains
        // - the top position in pixel of the top left corner
        // - the left position in pixel of the top left corner
        // - the available height in pixel
        // - the available width in pixel
        // they are sorted from left to right

        // a block represent a block to be placed, it contains
        // - the height
        // - the width
        // - the jQuery block object
        // - its position in a group of blocks of the same size (or -1 if not part of a group)

        // a positioned block represented a block placed somewhere, it contains
        // - the block
        // - the slot

        // a position contain
        // - the list of slots
        // - the list of positioned blocks
        // - the total height

        return this.each(function (i, container) {
            // the block lists
            // all have an height, a width, and a block
            if (blocks.length == 0) {
                return;
            }

            var settings = $.extend({
                'containerWidth':$(container).innerWidth(),
                'maxTime':100
            }, options);

            var blockList = [];
            {
                for (var k = 0; k < blocks.length; k++) {
                    var blockJ = $(blocks[k]);
                    blockList.push([
                        blockJ.outerHeight(true),
                        blockJ.outerWidth(true),
                        blockJ,
                        -1
                    ]);
                }

                // sort the blocks by width then height
                blockList = blockList.sort(function (b1, b2) {
                    if (b2[1] == b1[1]) {
                        return b2[0] - b1[0];
                    } else {
                        return b2[1] - b1[1];
                    }
                });

                // find identical blocks
                for (k = 1; k < blockList.length; k++) {
                    if ((blockList[k][0] == blockList[k - 1][0]) && (blockList[k][1] == blockList[k - 1][1])) {
                        if (blockList[k - 1][3] == -1) {
                            blockList[k - 1][3] = 0;
                            blockList[k][3] = 1;

                        } else {
                            blockList[k][3] = blockList[k - 1][3] + 1;
                        }
                    }
                }
            }

            var minBlockWidth = blockList[blockList.length - 1][1];
            var containerWidth = settings.containerWidth;
            var maxHeight = Number.POSITIVE_INFINITY;
            var timeout = false;

            function sameHeightSameWidth(slots, slotIndex) {
                // block is the same than the slot, just drop the slot
                var r = slots.slice(0);
                r.splice(slotIndex, 1);
                return r;
            }

            function sameHeightNarrower(slots, slotIndex, slot, block) {
                // block is the same height but narrower

                var r = slots.slice(0);
                if ((slots.length > (slotIndex + 1)) &&
                    (slots[slotIndex + 1][1] == (slot[1] + block[1])) &&
                    (slots[slotIndex + 1][3] == (slot[3] - block[1]))) {
                    // wannabe new slot is aligned with the next slot
                    // so instead of adding a new slot
                    // we increase the height of the next one
                    r.splice(slotIndex, 2,
                        [
                            slots[slotIndex + 1][0],
                            slots[slotIndex + 1][1],
                            (slots[slotIndex + 1][2] + block[0]),
                            slots[slotIndex + 1][3]
                        ]);
                } else {
                    // we will add a new slot if it is wide enough
                    var availableWidth = slot[3] - block[1];
                    if (availableWidth >= minBlockWidth) {
                        r.splice(slotIndex, 1, [
                            slot[0],
                            slot[1] + block[1],
                            block[0],
                            availableWidth
                        ]);
                    } else {
                        r.splice(slotIndex, 1);
                    }
                }
                return r;
            }

            function smallerNarrower(slots, slotIndex, slot, block) {
                // block is smaller and narrower than the slot

                var r = slots.slice(0);
                if ((slots.length > (slotIndex + 1)) &&
                    (slots[slotIndex + 1][1] == (slot[1] + block[1])) &&
                    (slots[slotIndex + 1][3] == (slot[3] - block[1]))) {
                    // wannabe new slot is aligned with the next slot
                    if (slotIndex == 0) {
                        // the current slot is the first one
                        // move it to the bottom and increase height of next one
                        r.splice(0, 2,
                            [
                                slot[0] + block[0],
                                0,
                                Number.POSITIVE_INFINITY,
                                slot[3]
                            ],
                            [
                                slots[slotIndex + 1][0],
                                slots[slotIndex + 1][1],
                                (slots[slotIndex + 1][2] + block[0]),
                                slots[slotIndex + 1][3]
                            ]
                        );
                    } else {
                        // current slot is not the first one
                        // we will increase the height of next slot
                        if ((slot[0] + block[0]) == slots[slotIndex - 1][0]) {
                            // bottom of block will be at same height that
                            // the previous block's slot => the current slot disappear
                            r.splice(slotIndex, 2,
                                [
                                    slots[slotIndex + 1][0],
                                    slots[slotIndex + 1][1],
                                    (slots[slotIndex + 1][2] + block[0]),
                                    slots[slotIndex + 1][3]
                                ]
                            );
                        } else {
                            r.splice(slotIndex, 2,
                                [ slot[0] + block[0],
                                    slot[1],
                                    (slot[2] - block[0]),
                                    slot[3]
                                ],
                                [
                                    slots[slotIndex + 1][0],
                                    slots[slotIndex + 1][1],
                                    (slots[slotIndex + 1][2] + block[0]),
                                    slots[slotIndex + 1][3]
                                ]
                            );
                        }
                    }
                } else {
                    // we will add a new slot if it is wide enough
                    var availableWidth = (slot[3] - block[1]);
                    if (availableWidth >= minBlockWidth) {
                        r.splice(slotIndex, 1,
                            [ slot[0] + block[0],
                                slot[1],
                                (slot[2] - block[0]),
                                slot[3]
                            ],
                            [
                                slot[0],
                                slot[1] + block[1],
                                block[0],
                                availableWidth
                            ]);
                    } else {
                        r.splice(slotIndex, 1,
                            [
                                (slot[0] + block[0]),
                                slot[1],
                                (slot[2] - block[0]),
                                slot[3]
                            ]);
                    }
                }
                return r;
            }

            // smaller but same width
            function smallerSameWidth(slots, slotIndex, slot, block) {
                var r = slots.slice(0);
                r.splice(slotIndex, 1,
                    [
                        slot[0] + block[0],
                        slot[1],
                        (slot[2] - block[0]),
                        slot[3]
                    ]);
                return r;
            }

            /**
             * Add the next block in a specific slot.
             * @params position the original position
             * @param positionedBlock the positioned block
             * @param slotIndex the slot index
             * @param height the height of the new position
             * @param remainingBlocks the blocks that have to be placed
             * @param currentGroupPosition the position of the occupied slots in the current group of blocks with same size
             *          as a list of positions
             * @param currentGroupPositions the positions already reached in the current group of blocks with same size
             *         it's an array of trees
             * @return the position requiring the lowest vertical space
             */
            function addNextBlockInSlot(position, positionedBlock, slotIndex, height, remainingBlocks, currentGroupPosition, currentGroupPositions) {
                var block = positionedBlock[0];
                var slot = positionedBlock[1];
                // if the block is part of a group
                if (block[3] != -1) {

                    // we will check if we already reached this position
                    // in the current group

                    // calculate the representation of the position
                    if (block[3] == 0) {
                        // it's the first block of a group of blocks of the same size
                        currentGroupPositions = [];
                        nextGroupPosition = [slot[0] * containerWidth + slot[1]];
                    } else if (block[3] >= 1) {
                        // in a group of positions but not the first one
                        var nextGroupPosition = currentGroupPosition.slice(0);
                        var currentSlotPosition = slot[0] * containerWidth + slot[1];

                        // insert the position at the right place in the list
                        // to keep it sorted
                        var positionFound = false;
                        for (var k = 0; (!positionFound) && k < currentGroupPosition.length; k++) {
                            if (currentGroupPosition[k] > currentSlotPosition) {
                                positionFound = true;
                                nextGroupPosition.splice(k, 0, currentSlotPosition);
                            }
                        }
                        if (!positionFound) {
                            nextGroupPosition.push(currentSlotPosition);
                        }

                        // look at the positions with the same number of slots
                        // and check if it's already here
                        // the previous positions are represented by a tree
                        // of hashes where the keys are the positions' ids
                        var c = currentGroupPositions[nextGroupPosition.length];
                        if (c != null) {
                            var identicalFound = true;
                            for (var i = 0; identicalFound && (i < nextGroupPosition.length); i++) {
                                var n = c[nextGroupPosition[i]];
                                if (!n) {
                                    identicalFound = false;
                                    for (var j = i; j < nextGroupPosition.length; j++) {
                                        c = c[nextGroupPosition[j]] = {}
                                    }
                                } else {
                                    c = n;
                                }
                            }
                            if (identicalFound) {
                                return null;
                            }

                        } else {
                            // no position with the same number of slots
                            // => create it with the current position
                            c = currentGroupPositions[nextGroupPosition.length] = {};
                            for (i = 0; i < nextGroupPosition.length; i++) {
                                c = c[nextGroupPosition[i]] = {}
                            }
                        }

                    }
                }

                // calculate the new slots then recurse
                var newSlots = [];
                if (slot[2] == block[0]) {
                    // the block has the same height than the slot
                    if (slot[3] == block[1]) {
                        // same height and same width
                        newSlots = sameHeightSameWidth(position[0], slotIndex);
                    } else {
                        // same height but narrower
                        newSlots = sameHeightNarrower(position[0], slotIndex, slot, block);
                    }
                } else {
                    // the blocks is smaller
                    if (block[1] == slot[3]) {
                        // same width but smaller
                        newSlots = smallerSameWidth(position[0], slotIndex, slot, block);
                    } else {
                        // smaller width and smaller height
                        newSlots = smallerNarrower(position[0], slotIndex, slot, block);
                    }
                }

                var newBlocks = position[1].slice(0);
                newBlocks.splice(-1, 0, positionedBlock);

                return addNextBlock(
                    [
                        newSlots,
                        newBlocks,
                        height
                    ],
                    remainingBlocks,
                    currentGroupPositions,
                    nextGroupPosition
                );
            }

            /**
             * Add the next block to a position in all possible manners,
             * then call itself with the remaining blocks.
             * @params position the original position
             * @param blocks the remaining blocks
             * @param currentGroupPosition the position of the occupied slots in the current group of blocks with same size
             * @param currentGroupPositions the positions already reached in the current group of blocks with same size
             *         it's an array of array
             * @return the position requiring the lowest vertical space
             */
            function addNextBlock(position, blocks, currentGroupPositions, currentGroupPosition) {
                if (timeout) {
                    return null;
                }
                var bestResult = null;
                var block = blocks[0];

                var remainingBlocks = blocks.slice(1);
                var positionedBlocks = position[1];

                // we iterate from end to beginning since the slots are
                // sorted from the left
                // so we have a chance to put it higher
                for (var slotIndex = (position[0].length - 1); (!timeout) && slotIndex >= 0; slotIndex--) {
                    var slot = position[0][slotIndex];
                    // check if the slot is large enough
                    // and if it's not too high
                    if (((slot[0] + block[0]) < maxHeight) &&
                        (slot[2] >= block[0]) &&
                        (slot[3] >= block[1])) {

                        var positionedBlock = [
                            block,
                            slot
                        ];

                        // get the max, the max function is just much slower
                        var blockHeight = slot[0] + block[0];
                        var height = (position[2] > blockHeight) ? position[2] : blockHeight;

                        if (blocks.length == 1) {
                            // it's the last block
                            // => no need to update the slots or anything
                            if (height <= maxHeight) {
                                maxHeight = height;
                                var newBlocks = positionedBlocks.slice(0);
                                newBlocks.splice(-1, 0, positionedBlock);
                                bestResult = [
                                    [],
                                    newBlocks,
                                    height
                                ];
                            }
                        } else {
                            var candidate = addNextBlockInSlot(
                                position,
                                positionedBlock,
                                slotIndex,
                                height,
                                remainingBlocks,
                                currentGroupPosition,
                                currentGroupPositions
                            );

                            if (candidate && (candidate[2] <= maxHeight)) {
                                bestResult = candidate;
                            }
                        }
                    }
                }
                return bestResult;
            }

            function bestFit(blocksList) {
                if (settings.maxTime != -1) {
                    window.setTimeout(function () {
                        timeout = true;
                    }, settings.maxTime);
                }
                return addNextBlock(
                    [
                        [
                            [0, 0, Number.POSITIVE_INFINITY, containerWidth]
                        ],
                        [],
                        0
                    ],
                    blocksList,
                    [],
                    []
                );
            }

            var position = bestFit(blockList);
            if (position) {
                for (var j = 0; j < position[1].length; j++) {
                    var positionedBlock = position[1][j];
                    $(positionedBlock[0][2]).
                        css('position', 'absolute').
                        css('top', positionedBlock[1][0]).
                        css('left', positionedBlock[1][1]);
                }
                $(container).
                    css('position', 'relative').
                    css('height', position[2]);
            }
        });

    };
})(jQuery);