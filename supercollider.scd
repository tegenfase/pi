
(
s.waitForBoot({
	var c = Condition.new;
	var numOfChannels = 16;


	MIDIClient.init;
	MIDIIn.connectAll;

	s.sync(c);
	"[!] Writing synthdefs to: ".post; SynthDef.synthDefDir.postln;
	SynthDef.new(\reverb, {
		arg in = 0, mix = 1, room = 1, damp = 0.5, gain = 1, out = 0;
		var sig;
		sig = In.ar(in, 2);
		sig = FreeVerb2.ar(sig[0],sig[1], mix, room, damp, gain);

		// sig = SVF.ar(sig, 500, 0.1, 0, 1, 1, 0,);
		Out.ar(out,sig);
	}).store;


	SynthDef.new(\sampler2, {
		arg amp=0.9, out=0, pan = 0.5, buf, start=0, end=1, loop=0, interp=2,
		fxBus1 = 0, fxLvl1 = 0, rate=1, trigbus = 0, hpf = 0, lpf = 0, bits=1, limit = 1;
		var windowSize = s.options.blockSize;
		var sig, ptr, env, framesInBuffer, sampleRateBuffer, trig, length;

		// ptr = Line.ar(0, BufFrames.kr(buf)-1, BufDur.kr(buf) * rate.midiratio);
		// If not specified play till end


		framesInBuffer = BufFrames.kr(buf);
		sampleRateBuffer = BufSampleRate.kr(buf);

		length = BufDur.kr(buf)*end*rate.midiratio;

		trig = InTrig.kr(trigbus);
		ptr = Phasor.ar(
			trig: trig,
			rate: BufRateScale.kr(buf)*rate.midiratio,
			start: Clip.kr(start*framesInBuffer,0,framesInBuffer).trunc(windowSize),
			end: Clip.kr(end*framesInBuffer,start,framesInBuffer).trunc(windowSize),
			resetPos: Clip.kr(start*framesInBuffer,0,framesInBuffer),
		);
		env = EnvGen.ar(envelope:
			Env([0,1,0],[0.001,0.9],\cubed),
			gate: trig, timeScale: (framesInBuffer/sampleRateBuffer)*end/rate.midiratio);

		sig = BufRd.ar(2, buf, ptr, loop, interp);

		sig = (sig*amp.linexp(0,1,0.001,2)).softclip;

		sig = LPF.ar(HPF.ar(sig,hpf.linexp(0,1,20,20000)),lpf.linexp(0,1,20,20000));

		if(buf.numChannels==1,{
			sig = Pan2.ar(sig[0], (pan*2)-1, env);
		},{
			sig = Balance2.ar(sig[0],sig[1],(pan*2)-1, env);
		});

		Out.ar(out, sig);
		Out.ar(fxBus1, sig*fxLvl1);
	}).store;

	s.loadDirectory(SynthDef.synthDefDir,"Loaded Synthdefs");
	s.initTree;
	SynthDescLib.global.read();

	// Allocate multichannel control busses for each argument of the sampler2 synthdef and set them to their default value
	~bus = ();
	SynthDescLib.global.at(\sampler2).controlDict.sortedKeysValuesDo{| key value |
		key.post;
		"   ".post;
		value.rate.post;
		"   ".post;
		value.defaultValue.postln;
		switch(key,
			'buf',{},
			{
				~bus[key] = Bus.alloc(\control,s,numOfChannels);
				~bus[key].setn(value.defaultValue!numOfChannels);
		});

	};

    
	// Fill buffers from samples library directory
	~buffers = ();
	~samples[\filePaths]['USER']['0'].select{| item | item.class == PathName;
	}.sortedKeysValuesDo{|key, item, i|
		postln("LOADING BUFFER " ++ i ++ " : " ++ key ++ "\t@\t" ++ item.fullPath);
		~buffers[i] = Buffer.read(s,item.fullPath,action:{|buf|buf.numChannels.postln;});

	};

    ~buffers[\banks] = Dictionary.new;

    "LOADING BANKS".postln;
	~samples[\filePaths]['TEST'].select{| item | item.class == Dictionary;}.sortedKeysValuesDo{|key, item|
        
		postln("LOADING BANK: " ++ key);
        
        ~buffers[\banks][key] = Dictionary.new;
        item.select{| item | item.class == PathName;}.sortedKeysValuesDo{| sampleKey, sampleItem, i |
            postln("\t LOADING SAMPLE: " ++  sampleKey);
            ~buffers[\banks][key][sampleKey] = Buffer.read(s,sampleItem.fullPath);

            
        };

    };

    s.sync(c);


	~routing = ();
	~groups = ();
	// FX 1
	~routing[\fx1send] = Bus.alloc(\audio,s,2);

	~rev = Synth.new(\reverb,[\in, ~routing[\fx1send], \mix, 1], addAction:\addToTail);
	~rev.set( \room,0.5);

	~routing[\group] = {Bus.alloc(\audio,s,2)}!4;


	~synths = ();
	
    /*
    16.do{|i|
		~synths[i] = Synth.new(\sampler2,[\buf, ~buffers[i],\bufChannels, ~buffers[i].numChannels]);
	};
    */
    ~buffers[\banks].sortedKeysValuesDo{ | key, bank, i |
        postln("SAMPLER: " ++ i ++ "\tBANK: " ++ key ++ "\tSAMPLE: " ++ ~buffers[\banks][key].asSortedArray[0][0]);
        ~synths[i] = Synth.new(\sampler2,[\buf, ~buffers[\banks][key].asSortedArray[0][1], \bufChannels,~buffers[\banks][key].asSortedArray[0][1].numChannels]);

    };
    
	~bus.sortedKeysValuesDo{ | key bus |
		bus.getn(16).postln;
		key.postln;
		bus.postln;
		~synths.do{ | synth, i |
			~synths[i].set(key,bus.subBus(i,1).asMap);
			bus.subBus(i,1);
		}
	};
    ~synths.do{|synth, i|
		~synths[i].set(\trigbus, ~bus[\trigbus].subBus(i,1), \fxBus1, ~routing[\fx1send]);
	};

	// Wait for asynchronous commands
	s.sync(c);


	// CREATE SAMPLER NODES
	// ~sampler = ();
	// ~triggers = Bus.control(s,8);
	// 8.do{|i|~sampler[i] = Synth.new(\sampler2,[\buf,~buffer[i],
	//	\trigbus, ~triggers.index+i,\start, 0,\end, 1, \fxBus1, ~fxBus1])};
	~touchosc = NetAddr.new("192.168.2.2",57120);
	~osc = ();
	~osc[\address] = NetAddr.new("127.0.0.1",8000);
	~osc[\index] = 0;
	f = { |msg, time, addr|
		var keys, array;
		// Get path as string
		msg.postln;
		keys = msg[0].asString.findRegexp("[_0-9a-zA-Z]+",0);
		switch(keys[0][1],
			"index",{
				if(msg[1]!=0,{
					// "Index change detected : ".postln;
					~osc[\index] = (keys[2][1].asInteger - 1);

					~bus[\trigbus].subBus(~osc[\index],1).set(1);

					~bus.pairsDo({arg key, value;
						'/bus/'++key.asSymbol;
						value.subBus(~osc[\index],1).getSynchronous;
						~touchosc.sendMsg(*[
							'/bus/'++key.asSymbol,
							value.subBus(~osc[\index],1).getSynchronous
						]);

					});
				},{});
				~touchosc.sendMsg(msg[0],msg[1]);
			},
			"sampler",{
				~osc[\address].sendMsg("/sampler/menu/1/values","{\"AKSJD\": 1,\"HELP\": 2}");
			},
			"bus",{

				postf("Parameter captured: % Value: %\n", keys[1][1],msg[1]);
				if((keys[2][1]!=nil),{
					~osc[\index] = keys[2][1].asInteger;
				},{});

				if((~bus.findMatch(keys[1][1].asSymbol)!=nil),{
					var value;
					//postf("Parameter captured: % Value: %\n", keys[1][1],msg[1]);
					switch(keys[1][1],
						"hpf",{
							~touchosc.sendMsg(msg[0],msg[1]);
							value = msg[1].linexp(0, 1, 20, 20000, clip: 'minmax');
							~touchosc.sendMsg(msg[0]++'/label',value.round);

						},
						"lpf",{
							~touchosc.sendMsg(msg[0],msg[1]);
							value = msg[1].linexp(0, 1, 20000, 20, clip: 'minmax');
							~touchosc.sendMsg(msg[0]++'/label',value.round);
						},
						{});
					~bus[keys[1][1].asSymbol].subBus(~osc[\index],1).set(msg[1]);


				},{if((keys[1][1]=="filter"),{
					~touchosc.sendMsg(msg[0],msg[1]);
					~bus[\hpf].subBus(~osc[\index],1).set(msg[1]);
					~bus[\lpf].subBus(~osc[\index],1).set(msg[2]);
				},{});
				"Parameter not found!".postln;});

			},
			{}
		);

	};
	thisProcess.addOSCRecvFunc(f);
	// MIDI Set-Up

	MIDIdef.noteOn(\trigger,{|val, num, chan, src|
		//[val,num,chan,src].postln;
		~bus[\trigbus].subBus((chan),1).set(1);
		~bus[\rate].subBus(chan,1).set((num-60));
		//~bus[\trigbus].setn(val.asBinaryDigits.reverse).postln;
	});
	//MIDIdef.new(\all,{|val, num, chan, src|
	//[val,num,chan,src].postln;
	//});
	MIDIdef.midiClock(\clock, {|a b c| postf("A: % B: % C: % TIME: %\n",a,b,c,thisThread.seconds;)});



	p = SerialPort.new("/dev/ttyAMA0",baudrate:115200, stopbit:1, parity: nil);
	r= Routine({
		var rx;
		inf.do{|i|
			rx=p.read;
			switch(rx,
				$T.ascii,{
					rx = p.read;
					~bus[\trigbus].setn(rx.asBinaryDigits.reverse).postln;
					//~s1 = Synth.new(\sampler2, [\t_gate, 1, \buf, ~b[0],\start, 0,\length, 0.1,\rate,0]);
				},
				$S.ascii,{
					p.read;
					p.read;
				},
				$M.ascii,{
					p.read;
				}

			);

		};
	}).play;

});
// READ SERIAL PORT ROUTINE
// ~sampler[1] = Synth(\sampler2,[\trigbus, ~triggers.index, \buf,~buffer[0],\start, 0,\length, 0.1]);
)




