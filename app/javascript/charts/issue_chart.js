import Chart from 'chart.js/auto';

export default class IssueChart {
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
      type: 'bar',
      data: {
        labels: [],
        datasets: [
          {
            label: 'Entries',
            data: [],
            backgroundColor: '#1f77b4'
          },
          {
            label: 'Severity',
            data: [],
            type: 'line',
            yAxisID: 'y2',
            borderColor: '#ff7f0e',
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        legend: {
          display: false
        },
        scales: {
          x: {
            type: 'category',
            ticks: {
              autoSkip: false,
              maxRotation: 15,
              minRotation: 15
            }
          },
          y: {
            position: 'outer',
            title: {
              display: true,
              text: ''
            }
          }
        },
        plugins: {
            legend: {
              display: false
            }
        }
      }
    });
  }

  updateDataset(data) {
    if (!this.chartInstance) {
      return;
    }

    const { labels, entryNames, severityIndexForIssue } = data;

    this.chartInstance.data.labels = labels;
    this.chartInstance.data.datasets[0].data = entryNames;
    this.chartInstance.data.datasets[1].data = severityIndexForIssue;
    this.chartInstance.update();
  }
};
