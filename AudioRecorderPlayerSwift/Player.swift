//
//  Player.swift
//  AudioRecorderPlayerSwift
//
//  Created by Max Harris on 11/6/20.
//

import AudioToolbox
import Foundation

func outputCallback(inUserData: UnsafeMutableRawPointer?, inAQ: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
    guard let player = inUserData?.assumingMemoryBound(to: Player.PlayingState.self) else {
        print("missing user data in output callback")
        return
    }

    let numBytes: Int = Int(bufferByteSize)
    let endIndex = min(audioData.count, player.pointee.end)

    if player.pointee.start >= audioData.count {
        player.pointee.running = false
        print("found end of audio data")
        return
    }

    let slice = audioData[player.pointee.start ..< endIndex]

    let sliceCount = slice.count
    player.pointee.start += numBytes
    player.pointee.end += sliceCount

    //    print("slice:", slice, "player.pointee.start:", player.pointee.start, "player.pointee.end:", player.pointee.end)
    print("numBytes:", numBytes, "sliceCount:", sliceCount)

    memcpy(inBuffer.pointee.mAudioData, Array(slice), sliceCount)
    inBuffer.pointee.mAudioDataByteSize = UInt32(sliceCount)
    check(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil))
}

struct Player {
    let bufferCount = 3

    struct PlayingState {
        var packetPosition: UInt32 = 0
        var running: Bool = false
        var start: Int = 0
        var end: Int = Int(bufferByteSize)
    }

    init() {
        var playingState: PlayingState = PlayingState()
        var queue: AudioQueueRef?
        check(AudioQueueNewOutput(&audioFormat, outputCallback, &playingState, nil, nil, 0, &queue))

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: bufferCount)

        playingState.running = true

        for i in 0 ..< bufferCount {
            check(AudioQueueAllocateBuffer(queue!, bufferByteSize, &buffers[i]))
            outputCallback(inUserData: &playingState, inAQ: queue!, inBuffer: buffers[i]!)

            if !playingState.running {
                break
            }
        }

        check(AudioQueueStart(queue!, nil))

        print("Playing\n")
        repeat {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.25, false)
        } while playingState.running

        // delay to ensure queue plays out buffered audio
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 2, false)

        playingState.running = false
        check(AudioQueueStop(queue!, true))
        check(AudioQueueDispose(queue!, true))
    }
}
