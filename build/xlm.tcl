database -open waves -shm -default
simvision window new WaveWindow -name "Waveform"
simvision waveform using {Waveform}
simvision input ../signals_dv.svwf
simvision console submit -using simulator -wait no run
