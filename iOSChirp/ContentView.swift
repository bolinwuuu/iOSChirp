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
            VStack(alignment: .leading, spacing: 12) {
                HStack{
                    Text(chart_title)
                        .fontWeight(.semibold)
                        .font(.system(size: 40))
                }
                AnimatedChart();
            }
        }
        .frame(width: 700, height: 700, alignment: .top)
    }
    
    @ViewBuilder
    func AnimatedChart() -> some View {
        Chart(data, id: \.x_val) {
            LineMark(
                x: .value("Time", $0.x_val),
                y: .value("Waveform Value", $0.y_val)
            )
        }
        .chartXScale(domain:0...test.max_time())
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text("Time (s)")
                .font(.system(size: 30))
            
        }
        .chartYAxisLabel(position: .leading) {
            Text(y_label)
                .font(.system(size: 30))
                //.rotationEffect(Angle(degrees: 0))
        }
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


