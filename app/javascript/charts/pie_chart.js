import Chart from 'chart.js/auto';

export default class EntryChart {
  constructor(chartElementId) {
    this.chartElementId = chartElementId;
    this.chartInstance = null;
  }

  initializeChart() {
    const chartElement = document.getElementById(this.chartElementId);

    if (!chartElement) {
      return;
    };

    const ctx = chartElement.getContext('2d');
    const chartInstance = Chart.getChart(ctx);

    if (chartInstance) {
      this.chartInstance = chartInstance;
      return;
    };

    this.chartInstance = this.createChart(ctx);
  }

  createChart(ctx) {
    return new Chart(ctx, {
      type: 'pie',
      data: {
        labels: [],
        datasets: [
          {
            data: [],
            backgroundColor: [
              '#4dc9f6',
              '#f67019',
              '#f53794',
              '#537bc4',
              '#acc236',
              '#166a8f',
              '#00a950',
              '#58595b',
              '#8549ba'
            ]
          }
        ]
      },
      options: {
        responsive: true
      }
    });
  }

  updateDataset(data) {
    if (!this.chartInstance) {
      return;
    }

    const { labels, entryNames } = data;

    this.chartInstance.data.labels = labels;
    this.chartInstance.data.datasets[0].data = entryNames;
    this.chartInstance.update();
  }
};
