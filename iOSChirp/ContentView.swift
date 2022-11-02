//
//  ContentView.swift
//  iOSChirp
//
//  Created by Bolin Wu on 10/1/22.
//

import SwiftUI
import Charts


struct ContentView: View {
    
    var body: some View {
        
        VStack {
            List {
                /*
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack{
                            Text("Waveform in Time")
                                .fontWeight(.semibold)
                                .font(.system(size: 40))
                        }
                        HStack(alignment: .center, spacing: 0) {
                            Text("h(t) [arb. units]")
                                .rotationEffect(Angle(degrees: -90))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .font(.system(size: 30))
                                .frame(width: 60)
                                .opacity(0.4)
                                 //.foregroundColor(.red)
                            VStack {
                                WaveformChart()
                            }
                             
                        }
                        //WaveformChart();
                    }
                    .frame(width: 700, height: 450, alignment: .top)
                }*/
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack{
                            Text("Frequency vs Time")
                                .fontWeight(.semibold)
                                .font(.system(size: 40))
                        }
                        HStack(alignment: .center, spacing: 0) {
                            Text("Frequency (Hz)")
                                .rotationEffect(Angle(degrees: -90))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .font(.system(size: 30))
                                .frame(width: 60)
                                .opacity(0.4)
                                //.foregroundColor(.red)
                            VStack {
                                FreqencyChart()
                            }
                            
                        }
                        //FreqencyChart();
                    }
                    .frame(width: 700, height: 450, alignment: .top)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack{
                            Text("Waveform Spectrogram")
                                .fontWeight(.semibold)
                                .font(.system(size: 40))
                        }
                        HStack(alignment: .center, spacing: 0) {
                            Text("Frequency (Hz)")
                                .rotationEffect(Angle(degrees: -90))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .font(.system(size: 30))
                                .frame(width: 60)
                                .opacity(0.4)
                            Spectrogram();
                        }
                    }
                    .frame(width: 700, height: 450, alignment: .top)
                }

            }
            
        }
        //.frame(width: 700, height: 700, alignment: .top)
    }
    
    @ViewBuilder
    func WaveformChart() -> some View {
        Chart(waveData, id: \.x_val) {
            LineMark(
                x: .value("Time", $0.x_val),
                y: .value("Waveform Value", $0.y_val)
            )
        }
        .chartXScale(domain:0...test.max_time())
        .chartXAxisLabel (position: .bottom, alignment: .center) {
            Text("Time (s)")
                .font(.system(size: 30))
            
        }
        .chartYAxis {
            AxisMarks(position: .leading)

        }/*
        .chartYAxisLabel(position: .leading) {
            Text("h(t) [arb. units]")
                .font(.system(size: 30))
        }*/

    }
    
    @ViewBuilder
    func FreqencyChart() -> some View {
        Chart(freqData, id: \.x_val) {
            LineMark(
                x: .value("Time", $0.x_val),
                y: .value("Frequency", $0.y_val)
            )
        }
        .chartXScale(domain:0...test.max_time())
        .chartXAxisLabel (position: .bottom, alignment: .center) {
            Text("Time (s)")
                .font(.system(size: 30))
            
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYScale(type: .log)
        /*
        .chartYAxisLabel(position: .leading) {
            Text("Frequency (Hz)")
                .font(.system(size: 30))
                //.rotationEffect(Angle(degrees: 180))
                //.lineLimit(1)
                //.fixedSize(horizontal: true, vertical: false)
        }*/

    }
    
    
    func Spectrogram() -> some View {
        Image(uiImage: im)
            .resizable()
            .frame(width: 600, height: 350)
    }
        
    /*
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
    }*/
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


