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
    
    // waveform vector, for runMode 2
    var h: [Double]

    
    // initializer, all computations for the vectors above
    init(mass1: Double, mass2: Double) {
        m1 = mass1;
        m2 = mass2;
        
        // Implied chirp mass (governs frequency and amplitude evolution)
        // (PPNP text right after Eqn 74)
          
        var mchirp:Double = pow((m1*m2),(3/5))/pow((m1+m2),(1/5));

        // Physical constants

        let g:Double = 6.67e-11;
        let c:Double = 2.998e8;
        let pc:Double = 3.086e16;
        let msun:Double = 2.0e30;

        // Compute Schwarzchild radii of stars

        var r1 = 2 * g * m1 * msun / pow(c, 2);
        var r2 = 2 * g * m2 * msun / pow(c, 2);

        // Frequency coefficient
        // (Based on PPNP Eqn 73)

        var fcoeff:Double = (1/(8*Double.pi)) * pow(pow(5, 3), 1/8) * pow(pow(c, 3) / (g*mchirp*msun), 5/8);

        // Amplitude coefficient (assume source at 15 Mpc)
        // (Based on PPNP Eqn 74)

        var rMpc:Double = 15;
        var r = rMpc * 1e6 * pc;
        var hcoeff = (1/r) * pow(5*pow(g*mchirp*msun/pow(c, 2), 5)/c, 1/4);

        // Amplitude rescaling parameter

        let hscale:Double = 1e21;

        // frequency (Hz) when signal enters detector band

        let fbandlo:Double = 30;

        // Compute time remaining to coalescence from entering band
        // (Based on PPNP Eqn 73)

        var tau = pow(fcoeff/fbandlo, 8/3);

        // Debugging summary

        print("Starting chirp simulation with M1, M2, Mchirp = " + String(m1) + " " + String(m2) + " " + String(mchirp) + " " + "(Msun)");
        print("--> Schwarzchild radii = " + String(r1) + " " + String(r2) + "m");
        print("Distance to source r = " + String(rMpc) + " Mpc");
        print("Detection band low frequency = " + String(fbandlo) + "Hz\n--> Time to coalescence = " + String(tau) + " s\n");

        // Sampling rate (Hz) - fixed at 48 kHz for mp4 output

        let fsamp:Double = 48000;
        var dt = 1/fsamp;

        // Length of time to simulate (round up to nearest tenth of an integer second and add a tenth)

        var upperT = ceil(10*tau)/10 + 0.1;

        // Create time sample container

        sampleN = floor(fsamp*upperT);
        //var t = Array(0...Int(upperN)-1);
        t = Array(stride(from: 0, through: sampleN-1, by: 1));
        t = vDSP.multiply(dt, t);

        // Determine frequency (and then time) when Schwarzchild radii touch
        // (Use Kepler's 3rd law)
        // (Double orbital frequency to get GW frequency)

        var ftouch = 2 * (1/(2*Double.pi)) * pow(g*(m1+m2)*msun/pow(r1+r2,3), 1/2);
        var tautouch = pow(fcoeff/ftouch, 8/3);
        print("GW frequency when Schwarzchild radii touch: " + String(ftouch) + " Hz\n--> Occurs " + String(tautouch) + " seconds before point-mass coalescence\n");
        
        // Create frequency value vs time (up to last time sample before point-mass coalescence)
        // (Based on PPNP Eqn 73)
        
        //var minusdt = -dt;
        

        var vzero:Double = 0;
        var iTau:Double = floor(tau / dt);

        var lastSample = floor((pow(ftouch / fcoeff, -8/3) - tau) / -dt);
        var maxFreq:Double = pow(-lastSample * dt + tau, -3/8) * fcoeff;
        
        var freq1 = Array(stride(from: 0, through: lastSample, by: 1));
        vDSP.multiply(-dt, freq1, result: &freq1);
        //var freq1 = [Float](repeating: 0, count: Int(iTau) + 1);
        var freq2 = [Double](repeating: maxFreq, count: Int(sampleN - lastSample) - 1);
        /*
        vDSP_vramp(&vzero,
                   &minusdt,
                   &freq1,
                   vDSP_Stride(1),
                   vDSP_Length(iTau + 1));*/

        vDSP.add(tau, freq1, result: &freq1);
        //freq = freq.map{pow(Float($0), -3/8)};
        
        var exp = [Double](repeating: -3/8, count: freq1.count);
        freq = vForce.pow(bases: freq1, exponents: exp);
        vDSP.multiply(fcoeff, freq, result: &freq);
        freq += freq2;

        //Create amplitude value vs time (up to last time sample before touch)
        // (Based on PPNP Eqn 74)
        
        exp = [Double](repeating: -1/4, count: freq1.count);
        var amp = vForce.pow(bases: freq1, exponents: exp);
        amp = vDSP.multiply(hcoeff * hscale, amp);
        var amp2 = [Double](repeating: 0, count: Int(sampleN - lastSample) - 1);
        amp += amp2;
        
        // Generate strain signal in time domain

        var phi = [Double](repeating: 0, count: freq.count);
        // Cumulative sum of freq
        phi[0] = freq[0];
        for index in 1...freq.count - 1 {
            phi[index] = phi[index - 1] + freq[index];
        }
        vDSP.multiply(2 * Double.pi * dt, phi, result: &phi);
        
        h = vDSP.multiply(amp, vForce.sin(phi));
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
            var ret = [Coords(x_in: 0, y_in: 0)];
            return ret;
        }
    }
    
    func run_mode_2() -> [Coords] {
        var cd = [Coords](repeating: Coords(x_in: 0, y_in: 0), count: self.t.count);
        
        var idx = 0;
        while (idx < cd.count) {
            cd[idx].x_val = self.t[idx];
            cd[idx].y_val = self.h[idx];
            idx += 1;
        }
        
        return cd;
    }
    
    func run_mode_3() -> [Coords] {
        var cd = [Coords](repeating: Coords(x_in: 0, y_in: 0), count: self.t.count);
        
        var idx = 0;
        while (idx < cd.count) {
            cd[idx].x_val = self.t[idx];
            cd[idx].y_val = self.freq[idx];
            idx += 1;
        }
        
        return cd;
    }
    
    /*
    func run_mode_4() {
        vDSP.convert(amplitude: freq, toDecibels: &freq, zeroReference: Double(freq.count));
    }*/
    
    func max_time() -> Double {
        return t[t.count - 1];
    }
    
    func y_label(runMode: Int) -> String {
        if (runMode == 2) {
            return "h(t) [arb. units]";
        }
        if (runMode == 3) {
            return "Frequency (Hz)";
        }
        else {
            return " ";
        }
    }
    
    func chart_title(runMode: Int) -> String {
        if (runMode == 2) {
            return "Waveform in Time";
        }
        if (runMode == 3) {
            return "Frequency vs Time";
        }
        else {
            return " ";
        }
    }
    
};

var test = Run_Chirp(mass1: 5, mass2: 20);

var runMode = 3;

var data = test.run_mode(runMode: runMode);

var y_label = test.y_label(runMode: runMode);

var chart_title = test.chart_title(runMode: runMode);


