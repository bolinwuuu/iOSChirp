//
//  run_chirp.swift
//  iOSChirp
//
//  Created by Bolin Wu on 10/1/22.
//

import Foundation
import UIKit
import Accelerate
import Darwin
import SwiftUI
import Charts




struct Coords {
    var x_val: Double
    var y_val: Double
    
    init(x_in: Double, y_in: Double) {
        self.x_val = x_in;
        self.y_val = y_in;
    }
}


class Run_Chirp {
    
    // two input masses
    var m1: Double
    var m2: Double
    
    // number of samples, which is the size of the vectors below, t, freq, h
    var sampleN: Double
    
    // time vector, on the x axis
    var t: [Double]
    
    // frequency vector, for runMode 3
    var freq: [Double]
    
    //var freqw: [Double]
    
    // waveform vector, for runMode 2
    var h: [Double]
    
    // max value of h
    var max_h: Double
    
    // sample frequency
    var fsamp: Double
    

    
    // initializer, all computations for the vectors above
    init(mass1: Double, mass2: Double) {
        m1 = mass1;
        m2 = mass2;
        
        // Implied chirp mass (governs frequency and amplitude evolution)
        // (PPNP text right after Eqn 74)
          
        let mchirp:Double = pow((m1*m2),(3/5))/pow((m1+m2),(1/5));

        // Physical constants

        let g:Double = 6.67e-11;
        let c:Double = 2.998e8;
        let pc:Double = 3.086e16;
        let msun:Double = 2.0e30;
        
        

        // Compute Schwarzchild radii of stars

        let r1 = 2 * g * m1 * msun / pow(c, 2);
        let r2 = 2 * g * m2 * msun / pow(c, 2);

        // Frequency coefficient
        // (Based on PPNP Eqn 73)

        let fcoeff:Double = (1/(8*Double.pi)) * pow(pow(5, 3), 1/8) * pow(pow(c, 3) / (g*mchirp*msun), 5/8);

        // Amplitude coefficient (assume source at 15 Mpc)
        // (Based on PPNP Eqn 74)

        let rMpc:Double = 15;
        let r = rMpc * 1e6 * pc;
        let hcoeff = (1/r) * pow(5*pow(g*mchirp*msun/pow(c, 2), 5)/c, 1/4);

        // Amplitude rescaling parameter

        let hscale:Double = 1e21;

        // frequency (Hz) when signal enters detector band

        let fbandlo:Double = 30;

        // Compute time remaining to coalescence from entering band
        // (Based on PPNP Eqn 73)

        let tau = pow(fcoeff/fbandlo, 8/3);

        // Debugging summary

        print("Starting chirp simulation with M1, M2, Mchirp = " + String(m1) + " " + String(m2) + " " + String(mchirp) + " " + "(Msun)");
        print("--> Schwarzchild radii = " + String(r1) + " " + String(r2) + "m");
        print("Distance to source r = " + String(rMpc) + " Mpc");
        print("Detection band low frequency = " + String(fbandlo) + "Hz\n--> Time to coalescence = " + String(tau) + " s\n");

        // Sampling rate (Hz) - fixed at 48 kHz for mp4 output
        
        let downSample: Double = 10;
        fsamp = 48000 / downSample;
        let dt = 1/fsamp;

        // Length of time to simulate (round up to nearest tenth of an integer second and add a tenth)

        let upperT = ceil(10*tau)/10 + 0.1;

        // Create time sample container

        sampleN = floor(fsamp*upperT);

        t = Array(stride(from: 0, through: sampleN-1, by: 1));
        t = vDSP.multiply(dt, t);

        // Determine frequency (and then time) when Schwarzchild radii touch
        // (Use Kepler's 3rd law)
        // (Double orbital frequency to get GW frequency)

        let ftouch = 2 * (1/(2*Double.pi)) * pow(g*(m1+m2)*msun/pow(r1+r2,3), 1/2);
        let tautouch = pow(fcoeff/ftouch, 8/3);
        print("GW frequency when Schwarzchild radii touch: " + String(ftouch) + " Hz\n--> Occurs " + String(tautouch) + " seconds before point-mass coalescence\n");
        
        // Create frequency value vs time (up to last time sample before point-mass coalescence)
        // (Based on PPNP Eqn 73)
        
        //var minusdt = -dt;
        //var vzero:Double = 0;
        //var iTau:Double = floor(tau / dt);

        
        let lastSample = floor((pow(ftouch / fcoeff, -8/3) - tau) / -dt);
        
        let maxFreq:Double = pow(-lastSample * dt + tau, -3/8) * fcoeff;
        
        var freq1 = Array(stride(from: 0, through: lastSample, by: 1));
        
        
        vDSP.multiply(-dt, freq1, result: &freq1);
        vDSP.add(tau, freq1, result: &freq1);

        
        var exp = [Double](repeating: -3/8, count: freq1.count);
        
        
        freq = [Double](repeating: maxFreq, count: min(9 * freq1.count / 8, Int(sampleN)));
        var freq_temp = vForce.pow(bases: freq1, exponents: exp);
        vDSP.multiply(fcoeff, freq_temp, result: &freq_temp);
        cblas_dcopy(Int32(freq_temp.count), &freq_temp, 1, &freq, 1)
        
//        var freq = vForce.pow(bases: freq1, exponents: exp);
//        vDSP.multiply(fcoeff, freq, result: &freq);
//        let freq2 = [Double](repeating: maxFreq, count: min(Int(freq1.count / 8), Int(sampleN - lastSample) - 1));
//        freq += freq2;
        
        
        
        print("sampleN: ", sampleN)
        print("9/8 freq1 count: ", 9 * freq1.count / 8)
        print("1/8 freq1 count: ", freq1.count / 8)
        //print("freq2 count: ", freq2.count)
        print("freq count: ", freq.count)
        
        //Create amplitude value vs time (up to last time sample before touch)
        // (Based on PPNP Eqn 74)
   
        vDSP.fill(&exp, with: -1/4);

        
        var amp = [Double](repeating: 0, count: freq.count);
        vForce.pow(bases: freq1, exponents: exp, result: &freq1);
        vDSP.multiply(hcoeff * hscale, freq1, result: &freq1);
        cblas_dcopy(Int32(freq1.count), &freq1, 1, &amp, 1)
        
//        var amp = [Double](repeating: 0, count: freq.count);
//        var amp1 = vForce.pow(bases: freq1, exponents: exp);
//        vDSP.multiply(hcoeff * hscale, amp1, result: &amp1);
//        cblas_dcopy(Int32(amp1.count), &amp1, 1, &amp, 1)
         
        
        // Generate strain signal in time domain
        
        
        var phi = [Double](repeating: 0, count: freq.count);
        // Cumulative sum of freq
        phi[0] = freq[0];
        for index in 1...freq.count - 1 {
            phi[index] = phi[index - 1] + freq[index];
        }
        vDSP.multiply(2 * Double.pi * dt, phi, result: &phi);

        
        h = vDSP.multiply(amp, vForce.sin(phi));
        
        max_h = vDSP.maximum(h);
    } // initializer
    
    
    // currently runMode 2 and 3
    func run_mode(runMode: Int) -> [Coords] {
        if (runMode == 2) {
            return run_mode_2();
        }
        else if (runMode == 3) {
            return run_mode_3();
        }
        else {
            let ret = [Coords(x_in: 0, y_in: 0)];
            return ret;
        }
    }
    
    func run_mode_2() -> [Coords] {
        var cd = [Coords](repeating: Coords(x_in: 0, y_in: 0), count: self.freq.count);
        
        var idx = 0;
        while (idx < cd.count) {
            cd[idx].x_val = self.t[idx];
            cd[idx].y_val = self.h[idx];
            idx += 1;
        }
        
        return cd;
    }
    
    func run_mode_3() -> [Coords] {
        var cd = [Coords](repeating: Coords(x_in: 0, y_in: 0), count: self.freq.count);
        var idx = 0;
        while (idx < cd.count) {
            cd[idx].x_val = self.t[idx];
            cd[idx].y_val = self.freq[idx];
            idx += 1;
        }
        return cd;
    }
    
    
    func run_mode_4() -> UIImage {
        var bufferCount: Int = 40;

        //let piece_len = Int(sampleN) / bufferCount;
        let piece_len = Int(freq.count / bufferCount);

        
        
        let sc_no_padding = Int(pow(2, ceil(log2(Double(piece_len)))));
        
        let last_exp: Int = Int(log2(Double(sc_no_padding / 2))) - 1;
        //let last_idx: Int = Int(pow(2, floor(log2(Double(sampleCount / 2))))) - 1;
        
        // decide best 0-padding factor
        // trim upper segments, should be (last_exp + 1) if not
        let len_log_no_padding = (last_exp + 1) * Int(pow(2, Double(last_exp)));
        let zero_padding = max(Int(pow(2, floor(log2(9000 / Double(len_log_no_padding))))), 1)
        
        let sampleCount = sc_no_padding * zero_padding;

        
        var splitComplexRealInput = [Float](repeating: 0, count: sampleCount);
        var splitComplexImaginaryInput = [Float](repeating: 0, count: sampleCount);
        
        var freqDomainValues: [Float] = [];
        
        var magnitudes = [Float](repeating: 0, count: sampleCount);
        
        
        // adapted log scale y-axis
    
        let len_log = zero_padding * len_log_no_padding;
        //let len_log = last_exp * Int(pow(2, Double(last_exp))) * zero_padding;

        // data of a column in log scale
        var mag_log = [Float](repeating: 0, count: len_log);
        
        // start with 10 hz
        let start_idx = Int(floor(Double(sampleCount) / (fsamp / 20)))
        
        let bin_duplicate = 2;
        
//        print("sc_no_padding: ", sc_no_padding)
//        print("sampleCount: ", sampleCount)
//        print("last exp: ", last_exp)
//        print("piece len: ", piece_len)
        print("len log without pad: ", len_log_no_padding)
        print("zero padding: ", zero_padding)
        print("len log: ", len_log)
        print("start idx: ", start_idx)
//        print("t.count: ", t.count)
//        print("10th: ", start_idx)
        
        freqDomainValues.reserveCapacity(len_log * bufferCount * bin_duplicate)
        
        fill_mag_log(
            i: 0, zero_padding: zero_padding,
            magnitudes: &magnitudes,
            mag_log: &mag_log,
            splitComplexRealInput: &splitComplexRealInput,
            splitComplexImaginaryInput: &splitComplexImaginaryInput,
            piece_len: piece_len,
            sampleCount: sampleCount,
            start_idx: start_idx,
            last_exp: last_exp)
        
        for _ in 0..<bin_duplicate {
            freqDomainValues += mag_log
        }

        // i = 31 piece_len -> 32 piece_len
        //for i in stride(from: 3 * piece_len, to: (bufferCount) * piece_len, by: piece_len) {
        for i in stride(from: piece_len, to: bufferCount * piece_len, by: piece_len) {
            
            fill_mag_log(
                i: i, zero_padding: zero_padding,
                magnitudes: &magnitudes,
                mag_log: &mag_log,
                splitComplexRealInput: &splitComplexRealInput,
                splitComplexImaginaryInput: &splitComplexImaginaryInput,
                piece_len: piece_len,
                sampleCount: sampleCount,
                start_idx: start_idx,
                last_exp: last_exp)
            
            
            let mean_mag = vDSP.multiply(addition: (mag_log, freqDomainValues[freqDomainValues.count - len_log..<freqDomainValues.count]), 0.5)
            for _ in 0..<bin_duplicate / 2 {
                freqDomainValues += mean_mag;
            }
            for _ in 0..<bin_duplicate / 2 {
                freqDomainValues += mag_log;
            }
            //freqDomainValues += mag_log;
        }
        bufferCount *= bin_duplicate;
        // adapted log scale y-axis end

        /*
        print(sampleCount / 2)
        // linear scale y-axis
         for i in stride(from: 0, to: bufferCount * piece_len, by: piece_len) {
             /*
             if (truncate) {     // truncate
                 vDSP.convertElements(of: h[i..<i + sampleCount],
                                      to: &splitComplexRealInput);
             } else {            // 0-padding
                 vDSP.convertElements(of: h[i..<i + piece_len],
                                      to: &splitComplexRealInput);
             }*/
             
             vDSP.convertElements(of: h[i..<i + piece_len],
                                  to: &splitComplexRealInput);
             
             let splitComplexDFT = try? vDSP.DiscreteFourierTransform(previous: nil,
                                               count: sampleCount,
                                               direction: .forward,
                                               transformType: .complexComplex,
                                               ofType: Float.self);

             var splitComplexOutput = splitComplexDFT?.transform(real: splitComplexRealInput, imaginary: splitComplexImaginaryInput);

             let forwardOutput = DSPSplitComplex(
                 realp: UnsafeMutablePointer<Float>(&( splitComplexOutput!.real)),
                 imagp: UnsafeMutablePointer<Float>(&( splitComplexOutput!.imaginary)));

             vDSP.absolute(forwardOutput, result: &magnitudes);
             
             /*
             if (i == 20 * piece_len) {
                 print(vDSP.indexOfMaximum(magnitudes[0..<sampleCount / 2]))
             }*/
             
             freqDomainValues += magnitudes[0..<sampleCount / 2];
         }
        let len_log = sampleCount / 2;
        // linear scale y-axis end
        */
        
        
        let maxFreqVal = vDSP.maximum(freqDomainValues)
        let maxFloat = maxFreqVal * 1.2
        let minFloat = 0 - maxFreqVal * 0.1
        
        let rgbImageFormat: vImage_CGImageFormat = {
            guard let format = vImage_CGImageFormat(
                    //bitsPerComponent: 8,
                    //bitsPerPixel: 8 * 4,
                    bitsPerComponent: 8,
                    bitsPerPixel: 8 * 4,
                    colorSpace: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                    renderingIntent: .defaultIntent) else {
                fatalError("Can't create image format.")
            }
            
            return format
        }()
        
        /// RGB vImage buffer that contains a vertical representation of the audio spectrogram.
        var rgbImageBuffer: vImage_Buffer = {
            guard let buffer = try? vImage_Buffer(
                width: len_log,        //sampleCount / 2,
                height: bufferCount,
                bitsPerPixel: rgbImageFormat.bitsPerPixel) else {
                fatalError("Unable to initialize image buffer.")
            }
            return buffer
        }()

        /// RGB vImage buffer that contains a horizontal representation of the audio spectrogram.
        var rotatedImageBuffer: vImage_Buffer = {
            guard let buffer = try? vImage_Buffer(
                width: bufferCount,
                height: len_log,       //sampleCount / 2,
                bitsPerPixel: rgbImageFormat.bitsPerPixel)  else {
                fatalError("Unable to initialize rotated image buffer.")
            }
            return buffer
        }()
        
        //let maxFloats: [Float] = [255, maxFloat, maxFloat, maxFloat]
        //let minFloats: [Float] = [255, 0, 0, 0]
        let maxFloats: [Float] = [255, maxFloat, maxFloat, maxFloat]
        let minFloats: [Float] = [255, minFloat, minFloat, minFloat]
        
        freqDomainValues.withUnsafeMutableBufferPointer {
            var planarImageBuffer = vImage_Buffer(
                data: $0.baseAddress!,
                height: vImagePixelCount(bufferCount),
                width: vImagePixelCount(len_log),  //sampleCount / 2),
                rowBytes: (len_log) * MemoryLayout<Float>.stride)
                //rowBytes: sampleCount / 2 * MemoryLayout<Float>.stride)
            
            vImageConvert_PlanarFToARGB8888(
                &planarImageBuffer,
                &planarImageBuffer,
                &planarImageBuffer,
                &planarImageBuffer,
                &rgbImageBuffer,
                maxFloats,
                minFloats,
                vImage_Flags(kvImageNoFlags))
        }
        
        vImageTableLookUp_ARGB8888(
            &rgbImageBuffer,
            &rgbImageBuffer,
            nil,
            &redTable,
            &greenTable,
            &blueTable,
            vImage_Flags(kvImageNoFlags))
        
        vImageRotate90_ARGB8888(
            &rgbImageBuffer,
            &rotatedImageBuffer,
            UInt8(kRotate90DegreesCounterClockwise),
            [UInt8()],
            vImage_Flags(kvImageNoFlags))
        
        let result = try? rotatedImageBuffer.createCGImage(format: rgbImageFormat)
        //let result = try? rgbImageBuffer.createCGImage(format: rgbImageFormat)
        
        
        //let success = saveImage(image: UIImage(cgImage: result!))
        //print(success)
        return UIImage(cgImage: result!);
    }
    
    func fill_mag_log(
        i: Int,
        zero_padding: Int,
        magnitudes: inout [Float],
        mag_log: inout [Float],
        splitComplexRealInput: inout [Float],
        splitComplexImaginaryInput: inout [Float],
        piece_len: Int,
        sampleCount: Int,
        start_idx: Int,
        last_exp: Int
    ) {
        vDSP.convertElements(of: h[i..<i + piece_len],
                             to: &splitComplexRealInput);
        
        
        let splitComplexDFT = try? vDSP.DiscreteFourierTransform(previous: nil,
                                          count: sampleCount,
                                          direction: .forward,
                                          transformType: .complexComplex,
                                          ofType: Float.self);

        var splitComplexOutput = splitComplexDFT?.transform(real: splitComplexRealInput, imaginary: splitComplexImaginaryInput);

        let forwardOutput = DSPSplitComplex(
            realp: UnsafeMutablePointer<Float>(&( splitComplexOutput!.real)),
            imagp: UnsafeMutablePointer<Float>(&( splitComplexOutput!.imaginary)));

        vDSP.absolute(forwardOutput, result: &magnitudes);
        
        
        var idx: Int = start_idx;
        //var idx: Int = 0;
        var idx_log: Int = 0;
        // trim upper segments, should be 0...last_exp if not
        for cur_exp in 0...last_exp {
        //for cur_exp in 0..<last_exp {
            let forw = Int(pow(2, Double(cur_exp)));
            let backw = Int(pow(2, Double(last_exp - cur_exp)));
            var temp_idx = idx;
            //while (temp_idx < idx + forw * zero_padding) {
            while (temp_idx < min(idx + forw * zero_padding, sampleCount / 2)) {
                let temp_val = magnitudes[temp_idx];
                vDSP.fill(&mag_log[idx_log..<idx_log + backw], with: temp_val);
                idx_log += backw;
                temp_idx += 1;
            }
            idx = temp_idx;
        }
    }
    
    func max_time() -> Double {
        return t[t.count - 1];
    }
    
    func empty_data() -> [Coords] {
        return [Coords](repeating: Coords(x_in: 0, y_in: 10), count: 0);
    }
    
    func yaxis_scale() -> Double {
        return pow(10, ceil(log10(vDSP.maximum(freq))))
    }
    
    func xaxis_scale() -> Double {
        return t[freq.count - 1]
    }
    
};

var test = Run_Chirp(mass1: 30, mass2: 30);

var waveData = test.run_mode(runMode: 2);

var freqData = test.run_mode(runMode: 3);

let im = test.run_mode_4()

var emptyData = test.empty_data();




/*
func saveImage(image: UIImage) -> Bool {
    guard let data = image.pngData() else {
        return false
    }
    guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
        return false
    }
    //print(directory);
    do {
        try data.write(to: directory.appendingPathComponent("spectrogram.png")!)
        return true
    } catch {
        print(error.localizedDescription)
        return false
    }
}



func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}*/
