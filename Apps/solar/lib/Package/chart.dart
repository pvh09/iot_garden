import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:async';

class Chart extends StatefulWidget{
  double data;
  Chart({Key? key, required this.data}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _Chart();
  }
}

class _Chart extends State<Chart>{
  late List<LiveData> chartData;
  late ChartSeriesController _chartSeriesController;

  @override
  void initState() {
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 1), updateDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      title: ChartTitle(
        text: '${widget.data} °C',
        textStyle: const TextStyle(
          color: Colors.red,       // giữ nguyên đỏ cho giá trị
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        alignment: ChartAlignment.far,
      ),

      tooltipBehavior: TooltipBehavior(enable: true),

      series: <LineSeries<LiveData, int>>[
        LineSeries<LiveData, int>(
          onRendererCreated: (ChartSeriesController controller) {
            _chartSeriesController = controller;
          },
          dataSource: chartData,
          color: Colors.red, // 🔹 màu đường biểu đồ
          isVisibleInLegend: true,
          xValueMapper: (LiveData sales, _) => sales.time,
          yValueMapper: (LiveData sales, _) => sales.chartData,
        ),
      ],

      // 🔹 Trục X — “Thời gian (s)”
      primaryXAxis: NumericAxis(
        //majorGridLines: const MajorGridLines(color: Colors.white24),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(color: Colors.white),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        interval: 3,
        labelStyle: const TextStyle(
          color: Colors.white, // màu số trên trục X
        ),
        title: AxisTitle(
          text: 'Thời gian (s)',
          textStyle: const TextStyle(
            color: Colors.white, // 🔹 chữ trắng
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // 🔹 Trục Y — “Nhiệt độ (°C)”
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(color: Colors.white),
        majorTickLines: const MajorTickLines(color: Colors.white),
        //majorGridLines: const MajorGridLines(color: Colors.white24),
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: const TextStyle(
          color: Colors.white, // 🔹 màu chữ trục Y
        ),
        title: AxisTitle(
          text: 'Nhiệt độ (°C)',
          textStyle: const TextStyle(
            color: Colors.white, // 🔹 tiêu đề trắng
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      backgroundColor: const Color(0xFF292639),   // 🔹 nền tối
      plotAreaBackgroundColor: const Color(0xFF292639),
    );
  }


  int time = 24;
  // void updateDataSource(Timer timer) {
  //   chartData.add(LiveData(time++, (widget.data.round())));
  //   chartData.removeAt(0);
  //   _chartSeriesController.updateDataSource(
  //       addedDataIndex: chartData.length - 1, removedDataIndex: 0);
  // }

  void updateDataSource(Timer timer) {
    if (!mounted) return; // Ngừng khi widget bị hủy
    if (chartData.isEmpty) return; // Không có dữ liệu thì bỏ qua

    chartData.add(LiveData(time++, widget.data));
    if (chartData.length > 20) {
      chartData.removeAt(0);
    }

    _chartSeriesController.updateDataSource(
      addedDataIndexes: <int>[chartData.length - 1],
      removedDataIndexes: chartData.length > 20 ? <int>[0] : null,
    );
  }

  List<LiveData> getChartData() {
    return <LiveData>[
      LiveData(0, 0),
      LiveData(1, 0),
      LiveData(2, 0),
      LiveData(3, 0),
      LiveData(4, 0),
      LiveData(5, 0),
      LiveData(6, 0),
      LiveData(7, 0),
      LiveData(8, 0),
      LiveData(9, 0),
      LiveData(11, 0),
      LiveData(12, 0),
      LiveData(13, 0),
      LiveData(14, 0),
      LiveData(15, 0),
      LiveData(16, 0),
      LiveData(17, 0),
      LiveData(18, 0),
      LiveData(19, 0),
      LiveData(20, 0),
      LiveData(21, 0),
      LiveData(22, 0),
      LiveData(23, 0),

    ];
  }
}

class LiveData {
  final int time;
  final num chartData;
  LiveData(this.time, this.chartData);

}