var graphs = [];

var bg_satur = 0.6;
var bg_light = 1;
var bg_alpha = 1;

var bo_satur = 0.6;
var bo_light = 1;
var bo_alpha = 1;

var dict;
var locale;

function add_bar_chart(ctx, title, xlabels, ylabel, values) {
	var bo = [];
	var bg = [];

	title = localize(title, locale);
	for (var i = 0; i < xlabels.length; i++)
		xlabels[i] = localize(xlabels[i], locale);
	ylabel = localize(ylabel, locale);

	for (var i = 0, h = 0; i < xlabels.length; i++, h += (1 / xlabels.length) - 0.2*(1 / xlabels.length)*Math.cos(2*(i / xlabels.length)*Math.PI)) {
		bg.push(hsva_to_rgba_str(h , bg_satur , bg_light - 0.03*bg_light + 0.03*bg_light*Math.cos(2*h*Math.PI), bg_alpha));
		bo.push(hsva_to_rgba_str(h , bo_satur , bo_light - 0.03*bo_light + 0.03*bo_light*Math.cos(2*h*Math.PI), bo_alpha));
	}

	graphs.push(new Chart(
		ctx, {
			type: 'bar',
			data: {
				labels: xlabels,
				datasets : [{
					label: ylabel,
					data: values[0],
					backgroundColor: bg,
					borderColor: bo,
					borderWidth: 1
				}]
			},
			responsive: true,
			options: {
				title: {
					display: true,
					text: title,
				},
				legend: {
					display: false
				},
				scales: {
					yAxis: [{
						stacked: false,
						ticks: {
			            beginAtZero:true
		                }
					}]
				}
			}
		}
	));
}

function add_stacked_bar_chart(ctx, title, xlabels, ylabels, series) {
	var datasets = [];

	title = localize(title, locale);
	for (var i = 0; i < xlabels.length; i++)
		xlabels[i] = localize(xlabels[i], locale);
	for (var i = 0; i < ylabels.length; i++)
		ylabels[i] = localize(ylabels[i], locale);

	for (var i = 0, h = 0; i < series.length; i++, h += 1 / series.length) {
		var bg = [], bo = [];
		for (var j = 0; j < series[i].length; j++) {
			bg.push(hsva_to_rgba_str(h , bg_satur , bg_light - 0.03*bg_light + 0.03*bg_light*Math.cos(2*h*Math.PI), bg_alpha));
			bo.push(hsva_to_rgba_str(h , bo_satur , bo_light - 0.03*bo_light + 0.03*bo_light*Math.cos(2*h*Math.PI), bo_alpha));
		}

		datasets.push({
			label: ylabels[i],
			data: series[i],
			backgroundColor: bg,
			borderColor: bo,
			borderWidth: 1
		});
	}

	graphs.push(new Chart(
		ctx, {
			type: 'bar',
			data: {
				labels: xlabels,
				datasets : datasets
			},
			responsive: true,
			options: {
				title: {
					display: true,
					text: title,
				},
				legend: {
					display: true
				},
				scales: {
					yAxes: [{
				stacked: true
			}],
				    xAxes: [{
				stacked: true
			}]
				}
			}
		}
	));
}

function add_pie_chart(ctx, title, xlabels, values) {
	var bo = [];
	var bg = [];

	title = localize(title, locale);
	for (var i = 0; i < xlabels.length; i++)
		xlabels[i] = localize(xlabels[i], locale);

	for (var i = 0, h = 0; i < xlabels.length; i++, h += (1 / xlabels.length) - 0.2*(1 / xlabels.length)*Math.cos(2*(i / xlabels.length)*Math.PI)) {
		bg.push(hsva_to_rgba_str(h , bg_satur , bg_light - 0.03*bg_light + 0.03*bg_light*Math.cos(2*h*Math.PI), bg_alpha));
		bo.push(hsva_to_rgba_str(h , bo_satur , bo_light - 0.03*bo_light + 0.03*bo_light*Math.cos(2*h*Math.PI), bo_alpha));
	}

	graphs.push(new Chart(
		ctx, {
			type: 'pie',
			data: {
				labels: xlabels,
				datasets : [{
					label: "",
					data: values[0],
					backgroundColor: bg,
					borderColor: bo,
					borderWidth: 1
				}]
			},
			responsive: true,
			options: {
				title: {
					display: true,
					text: title,
				},
				legend: {
					display: true,
					position: 'right'
				}
			}
		}
	));
}

function hsva_to_rgba_str(h, s, v, a) {
	var r, g, b, i, f, p, q, t;
	if (arguments.length === 1) {
		s = h.s, v = h.v, h = h.h;
	}

	i = Math.floor(h * 6);
	f = h * 6 - i;
	p = v * (1 - s);
	q = v * (1 - f * s);
	t = v * (1 - (1 - f) * s);

	switch (i % 6) {
		case 0: r = v, g = t, b = p; break;
		case 1: r = q, g = v, b = p; break;
		case 2: r = p, g = v, b = t; break;
		case 3: r = p, g = q, b = v; break;
		case 4: r = t, g = p, b = v; break;
		case 5: r = v, g = p, b = q; break;
	}

	return 'rgba(' + Math.round(r * 255) + ', ' + Math.round(g * 255) + ', ' + Math.round(b * 255) + ', ' + a + ')';
}

function get_translations() {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
	    if (this.readyState == 4 && this.status == 200) {
	        dict = JSON.parse(this.responseText);
	    }
	    update_translations();
	};
	xmlhttp.open("GET", "/plugin/Koha/Plugin/StatChart/locale.json", true);
	xmlhttp.send();
}

function update_translations() {
	/* For graphs */
	for (var i = 0; i < graphs.length; i++) {
		graphs[i].options.title.text = localize(graphs[i].options.title.text, locale);
		graphs[i].data.labels.forEach(function(label, j, array){array[j] = localize(label, locale)});
		graphs[i].data.datasets.forEach(function(dataset, j, array){array[j].label = localize(dataset.label, locale)});

		graphs[i].update();
	}

	/* For tables */
	var td = document.getElementById('td-preset-0');
	for (var i = 0; td != undefined; i++, td = document.getElementById('td-preset-' + i)) {
		td.innerHTML = localize(td.innerHTML, locale);
	}
}

function localize(str, loc) {
	if (dict == undefined)
		return str;
	if (!(loc in dict) || !(str in dict[loc]))
		return str;
	return dict[loc][str];
}
