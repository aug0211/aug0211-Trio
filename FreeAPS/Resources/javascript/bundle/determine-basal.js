var freeaps_determineBasal;(()=>{var e={5546:(e,t,a)=>{var r=a(6880);function o(e,t){t||(t=0);var a=Math.pow(10,t);return Math.round(e*a)/a}function n(e,t){return"mmol/L"===t.out_units?o(.0555*e,1):Math.round(e)}e.exports=function(e,t,a,i,s,l,m,d,u,c,g,h,p,v){var f=i.min_bg,B=v.overrideTarget;const b=v.smbIsOff;var M=0,_="",y="",x="",S="",D="",w=0,T=0,C=0,U=0,G=0,O=0;const R=v.weightedAverage;var A=1,I=i.sens,j=i.carb_ratio;v.useOverride&&(I/=A=v.overridePercentage/100,j/=A);const F=i.weightPercentage,P=v.average_total_data;function E(e,t){var a=e.getTime();return new Date(a+36e5*t)}function q(e){var t=i.bolus_increment;.025!=t&&(t=.05);var a=e/t;return a>=1?o(Math.floor(a)*t,5):0}function W(e){function t(e){return e<10&&(e="0"+e),e}return t(e.getHours())+":"+t(e.getMinutes())+":00"}function k(e,t){var a=new Date("1/1/1999 "+e),r=new Date("1/1/1999 "+t);return(a.getTime()-r.getTime())/36e5}function L(e,t){var a=0,r=t,o=(e-t)/36e5,n=0,i=o,s=0;do{if(o>0){var l=W(r),m=p[0].rate;for(let e=0;e<p.length;e++){var d=p[e].start;if(l==d){if(e+1<p.length){o>=(s=k(p[e+1].start,p[e].start))?n=s:o<s&&(n=o)}else if(e+1==p.length){let t=p[0].start;o>=(s=24-k(p[e].start,t))?n=s:o<s&&(n=o)}a+=q((m=p[e].rate)*n),o-=n,console.log("Dynamic ratios log: scheduled insulin added: "+q(m*n)+" U. Bas duration: "+n.toPrecision(3)+" h. Base Rate: "+m+" U/h. Time :"+l),r=E(r,n)}else if(l>d)if(e+1<p.length){var u=p[e+1].start;l<u&&(o>=(s=k(u,l))?n=s:o<s&&(n=o),a+=q((m=p[e].rate)*n),o-=n,console.log("Dynamic ratios log: scheduled insulin added: "+q(m*n)+" U. Bas duration: "+n.toPrecision(3)+" h. Base Rate: "+m+" U/h. Time :"+l),r=E(r,n))}else if(e==p.length-1){o>=(s=k("23:59:59",l))?n=s:o<s&&(n=o),a+=q((m=p[e].rate)*n),o-=n,console.log("Dynamic ratios log: scheduled insulin added: "+q(m*n)+" U. Bas duration: "+n.toPrecision(3)+" h. Base Rate: "+m+" U/h. Time :"+l),r=E(r,n)}}}}while(o>0&&o<i);return a}if(g.length){let e=g.length-1;var z=new Date(g[e].timestamp),N=new Date(g[0].timestamp);if("TempBasalDuration"==g[0]._type&&(N=new Date),(M=(N-z)/36e5)<23.9&&M>21)G=L(z,(H=24-M,Z=z.getTime(),new Date(Z-36e5*H))),S="24 hours of data is required for an accurate tdd calculation. Currently only "+M.toPrecision(3)+" hours of pump history data are available. Using your pump scheduled basals to fill in the missing hours. Scheduled basals added: "+G.toPrecision(5)+" U. ";else M<21?(oe=!1,enableDynamicCR=!1):S=""}else console.log("Pumphistory is empty!"),oe=!1,enableDynamicCR=!1;var H,Z;for(let e=0;e<g.length;e++)"Bolus"==g[e]._type&&(U+=g[e].amount);for(let e=1;e<g.length;e++)if("TempBasal"==g[e]._type&&g[e].rate>0){w=e,O=g[e].rate;var $=g[e-1]["duration (min)"]/60,J=$,K=new Date(g[e-1].timestamp),Q=K,V=0;do{if(e--,0==e){Q=new Date;break}if("TempBasal"==g[e]._type||"PumpSuspend"==g[e]._type){Q=new Date(g[e].timestamp);break}var X=e-2;if(X>=0&&"Rewind"==g[X]._type){let e=g[X].timestamp;for(;X-1>=0&&"Prime"==g[X-=1]._type;)V=(g[X].timestamp-e)/36e5;V>=$&&(Q=e,V=0)}}while(e>0);var Y=(Q-K)/36e5;Y<J&&($=Y),C+=q(O*($-V)),e=w}for(let e=0;e<g.length;e++)if(0,0==g[e]["duration (min)"]||"PumpResume"==g[e]._type){let t=new Date(g[e].timestamp),a=t,r=e;do{if(r>0&&(--r,"TempBasal"==g[r]._type)){a=new Date(g[r].timestamp);break}}while(r>0);(a-t)/36e5>0&&(G+=L(a,t))}for(let e=g.length-1;e>0;e--)if("TempBasalDuration"==g[e]._type){let t=g[e]["duration (min)"]/60,a=new Date(g[e].timestamp);var ee=a;let r=e;do{if(--r,r>=0&&("TempBasal"==g[r]._type||"PumpSuspend"==g[r]._type)){ee=new Date(g[r].timestamp);break}}while(r>0);if(0==e&&"TempBasalDuration"==g[0]._type&&(ee=new Date,t=g[e]["duration (min)"]/60),(ee-a)/36e5-t>0){G+=L(ee,E(a,t))}}var te,ae={TDD:o(T=U+C+G,5),bolus:o(U,5),temp_basal:o(C,5),scheduled_basal:o(G,5)};M>21?(y=". Bolus insulin: "+U.toPrecision(5)+" U",x=". Temporary basal insulin: "+C.toPrecision(5)+" U",_=". Insulin with scheduled basal rate: "+G.toPrecision(5)+" U",D=S+(" TDD past 24h is: "+T.toPrecision(5)+" U")+y+x+_,tddReason=", Total insulin: "+o(T,2)+" U, "+o(U/T*100,0)+"% Bolus "+o((C+G)/T*100,0)+"% Basal"):tddReason=", TDD: Not enough pumpData (< 21h)";const re=e.glucose;var oe=h.useNewFormula;const ne=h.enableDynamicCR,ie=Math.min(i.autosens_min,i.autosens_max),se=Math.max(i.autosens_min,i.autosens_max);(se==ie||se<1||ie>1)&&(oe=!1,console.log("Dynamic ISF disabled due to current autosens settings"));const le=h.adjustmentFactor,me=i.min_bg;var de=!1,ue="",ce=1,ge="";P>0&&(ce=R/P),ge=ce>1?"Basal adjustment with a 24 hour  to total average (up to 14 days of data) TDD ratio (limited by Autosens max setting). Basal Ratio: "+(ce=o(ce=Math.min(ce,i.autosens_max),2))+". Upper limit = Autosens max ("+i.autosens_max+")":ce<1?"Basal adjustment with a 24 hour to  to total average (up to 14 days of data) TDD ratio (limited by Autosens min setting). Basal Ratio: "+(ce=o(ce=Math.max(ce,i.autosens_min),2))+". Lower limit = Autosens min ("+i.autosens_min+")":"Basal adjusted with a 24 hour to total average (up to 14 days of data) TDD ratio: "+ce,ge=", Basal ratio: "+ce,(i.high_temptarget_raises_sensitivity||i.exercise_mode||v.isEnabled)&&(de=!0),me>=118&&de&&(oe=!1,ue="Dynamic ISF temporarily off due to a high temp target/exercising. Current min target: "+me);var he=", Dynamic ratios log: ",pe=", AF: "+le,ve="BG: "+re+" mg/dl ("+(.0555*re).toPrecision(2)+" mmol/l)",fe="",Be="";const be=h.curve,Me=h.insulinPeakTime,_e=h.useCustomPeakTime;var ye=55,xe=65;switch(be){case"rapid-acting":xe=65;break;case"ultra-rapid":xe=50}_e?(ye=120-Me,console.log("Custom insulinpeakTime set to :"+Me+", insulinFactor: "+ye)):(ye=120-xe,console.log("insulinFactor set to : "+ye)),te=T,F<1&&R>0&&(T=R,console.log("Using weighted TDD average: "+o(T,2)+" U, instead of past 24 h ("+o(te,2)+" U), weight: "+F),Be=", Weighted TDD: "+o(T,2)+" U");const Se=h.sigmoid;var De="";if(oe){var we=I*le*T*Math.log(re/ye+1)/1800;fe=", Logarithmic formula"}if(oe&&Se){const e=ie,t=se-e,a=.0555*(re-i.min_bg);var Te=ce,Ce=se-1;1==se&&(Ce=se+.01-1);const r=Math.log10(1/Ce-e/Ce)/Math.log10(Math.E),o=a*le*Te+r;we=t/(1+Math.exp(-o))+e,fe=", Sigmoid function"}var Ue=j;const Ge=o(j,1);var Oe="",Re="";if(oe&&T>0){if(Oe=", Dynamic ISF/CR: On/",we>se?(ue=", Dynamic ISF limited by autosens_max setting: "+se+" ("+o(we,2)+"), ",Re=", Autosens/Dynamic Limit: "+se+" ("+o(we,2)+")",we=se):we<ie&&(ue=", Dynamic ISF limjted by autosens_min setting: "+ie+" ("+o(we,2)+"). ",Re=", Autosens/Dynamic Limit: "+ie+" ("+o(we,2)+")",we=ie),ne){Oe+="On";var Ae=we;we>1&&(Ae=(we-1)/2+1);var Ie=" CR: "+(Ue=o(Ue/Ae,2))+" g/U";j=Ue}else Ie=" CR: "+Ue+" g/U",Oe+="Off";const e=I/we;s.ratio=we,De=". Using Sigmoid function, the autosens ratio has been adjusted with sigmoid factor to: "+o(s.ratio,2)+". New ISF = "+o(e,2)+" mg/dl ("+o(.0555*e,2)+" (mmol/l). CR adjusted from "+o(Ge,2)+" to "+o(Ue,2),D+=he+ve+pe+fe+(ue+=Se?De:", Dynamic autosens.ratio set to "+o(we,2)+" with ISF: "+e.toPrecision(3)+" mg/dl/U ("+(.0555*e).toPrecision(3)+" mmol/l/U)")+Oe+Ie+Be}else D+=he+"Dynamic Settings disabled";console.log(D),oe||ne?oe&&i.tddAdjBasal?tddReason+=Oe+fe+Re+pe+ge:oe&&!i.tddAdjBasal&&(tddReason+=Oe+fe+Re+pe):tddReason+="";var je={},Fe=new Date;if(c&&(Fe=c),void 0===i||void 0===i.current_basal)return je.error="Error: could not get current basal rate",je;var Pe=r(i.current_basal,i)*A,Ee=Pe;v.useOverride&&(0==v.duration?console.log("Profile Override is active. Override "+o(100*A,0)+"%. Override Duration: Enabled indefinitely"):console.log("Profile Override is active. Override "+o(100*A,0)+"%. Override Expires in: "+v.duration+" min."));var qe=new Date;c&&(qe=c);var We,ke=new Date(e.date),Le=o((qe-ke)/60/1e3,1),ze=e.glucose,Ne=e.noise;We=e.delta>-.5?"+"+o(e.delta,0):o(e.delta,0);var He=Math.min(e.delta,e.short_avgdelta),Ze=Math.min(e.short_avgdelta,e.long_avgdelta),$e=Math.max(e.delta,e.short_avgdelta,e.long_avgdelta);(ze<=10||38===ze||Ne>=3)&&(je.reason="CGM is calibrating, in ??? state, or noise is high");if(ze>60&&0==e.delta&&e.short_avgdelta>-1&&e.short_avgdelta<1&&e.long_avgdelta>-1&&e.long_avgdelta<1&&("fakecgm"==e.device?(console.error("CGM data is unchanged ("+n(ze,i)+"+"+n(e.delta,i)+") for 5m w/ "+n(e.short_avgdelta,i)+" mg/dL ~15m change & "+n(e.long_avgdelta,2)+" mg/dL ~45m change"),console.error("Simulator mode detected ("+e.device+"): continuing anyway")):!0),Le>12||Le<-5?je.reason="If current system time "+qe+" is correct, then BG data is too old. The last BG data was read "+Le+"m ago at "+ke:0===e.short_avgdelta&&0===e.long_avgdelta&&(e.last_cal&&e.last_cal<3?je.reason="CGM was just calibrated":je.reason="CGM data is unchanged ("+n(ze,i)+"+"+n(e.delta,i)+") for 5m w/ "+n(e.short_avgdelta,i)+" mg/dL ~15m change & "+n(e.long_avgdelta,i)+" mg/dL ~45m change"),ze<=10||38===ze||Ne>=3||Le>12||Le<-5||0===e.short_avgdelta&&0===e.long_avgdelta)return t.rate>=Ee?(je.reason+=". Canceling high temp basal of "+t.rate,je.deliverAt=Fe,je.temp="absolute",je.duration=0,je.rate=0,je):0===t.rate&&t.duration>30?(je.reason+=". Shortening "+t.duration+"m long zero temp to 30m. ",je.deliverAt=Fe,je.temp="absolute",je.duration=30,je.rate=0,je):(je.reason+=". Temp "+t.rate+" <= current basal "+Ee+"U/hr; doing nothing. ",je);var Je,Ke,Qe,Ve,Xe=i.max_iob;if(void 0!==i.min_bg&&(Ke=i.min_bg),void 0!==i.max_bg&&(Qe=i.max_bg),void 0!==i.enableSMB_high_bg_target&&(Ve=i.enableSMB_high_bg_target),void 0===i.min_bg||void 0===i.max_bg)return je.error="Error: could not determine target_bg. ",je;Je=(i.min_bg+i.max_bg)/2;var Ye=i.exercise_mode||i.high_temptarget_raises_sensitivity||v.isEnabled,et=100,tt=160;if(tt=i.half_basal_exercise_target,v.isEnabled){const e=v.hbt;console.log("Half Basal Target used: "+n(e,i)+" "+i.out_units),tt=e}else console.log("Default Half Basal Target used: "+n(tt,i)+" "+i.out_units);if(Ye&&i.temptargetSet&&Je>et||i.low_temptarget_lowers_sensitivity&&i.temptargetSet&&Je<et||v.isEnabled&&i.temptargetSet&&Je<et){var at=tt-et;sensitivityRatio=at*(at+Je-et)<=0?i.autosens_max:at/(at+Je-et),sensitivityRatio=Math.min(sensitivityRatio,i.autosens_max),sensitivityRatio=o(sensitivityRatio,2),process.stderr.write("Sensitivity ratio set to "+sensitivityRatio+" based on temp target of "+Je+"; ")}else void 0!==s&&s&&(sensitivityRatio=s.ratio,0===B||B===i.min_bg||i.temptargetSet||(Je=B,console.log("Current Override Profile Target: "+n(B,i)+" "+i.out_units)),process.stderr.write("Autosens ratio: "+sensitivityRatio+"; "));if(i.temptargetSet&&Je<et&&oe&&re>=Je&&sensitivityRatio<we&&(s.ratio=we*(et/Je),s.ratio=Math.min(s.ratio,i.autosens_max),sensitivityRatio=o(s.ratio,2),console.log("Dynamic ratio increased from "+o(we,2)+" to "+o(s.ratio,2)+" due to a low temp target ("+Je+").")),sensitivityRatio&&!oe?(Ee=i.current_basal*A*sensitivityRatio,Ee=r(Ee,i)):oe&&i.tddAdjBasal&&(Ee=i.current_basal*ce*A,Ee=r(Ee,i),P>0&&(process.stderr.write("TDD-adjustment of basals activated, using tdd24h_14d_Ratio "+o(ce,2)+", TDD 24h = "+o(te,2)+"U, Weighted average TDD = "+o(R,2)+"U, (Weight percentage = "+F+"), Total data of TDDs (up to 14 days) average = "+o(P,2)+"U. "),Ee!==Pe*A?process.stderr.write("Adjusting basal from "+Pe*A+" U/h to "+Ee+" U/h; "):process.stderr.write("Basal unchanged: "+Ee+" U/h; "))),i.temptargetSet);else if(void 0!==s&&s&&(i.sensitivity_raises_target&&s.ratio<1||i.resistance_lowers_target&&s.ratio>1)){Ke=o((Ke-60)/s.ratio)+60,Qe=o((Qe-60)/s.ratio)+60;var rt=o((Je-60)/s.ratio)+60;Je===(rt=Math.max(80,rt))?process.stderr.write("target_bg unchanged: "+n(rt,i)+"; "):process.stderr.write("target_bg from "+n(rt,i)+" to "+n(rt,i)+"; "),Je=rt}var ot=n(Je,i);Je!=f&&(ot=0!==B&&B!==Je?n(f,i)+"→"+n(B,i)+"→"+n(Je,i):n(f,i)+"→"+n(Je,i));var nt=200,it=200,st=200;if(e.noise>=2){var lt=Math.max(1.1,i.noisyCGMTargetMultiplier);Math.min(250,i.maxRaw);nt=o(Math.min(200,Ke*lt)),it=o(Math.min(200,Je*lt)),st=o(Math.min(200,Qe*lt)),process.stderr.write("Raising target_bg for noisy / raw CGM data, from "+n(rt,i)+" to "+n(it,i)+"; "),Ke=nt,Je=it,Qe=st}var mt=Ke-.5*(Ke-40),dt=i.threshold_setting;dt>mt&&dt<=120&&dt>=65?(console.error("Threshold changed in settings from "+n(mt,i)+" to "+n(dt,i)+". "),mt=dt):console.error("Current threshold: "+n(mt,i));var ut="",ct=(o(I,1),I);if(void 0!==s&&s&&((ct=o(ct=I/sensitivityRatio,1))!==I?process.stderr.write("ISF from "+n(I,i)+" to "+n(ct,i)):process.stderr.write("ISF unchanged: "+n(ct,i)),ut+="Autosens ratio: "+o(sensitivityRatio,2)+", ISF: "+n(I,i)+"→"+n(ct,i)),console.error("CR:"+j),void 0===a)return je.error="Error: iob_data undefined. ",je;var gt,ht=a;if(a.length,a.length>1&&(a=ht[0]),void 0===a.activity||void 0===a.iob)return je.error="Error: iob_data missing some property. ",je;var pt=((gt=void 0!==a.lastTemp?o((new Date(qe).getTime()-a.lastTemp.date)/6e4):0)+t.duration)%30;if(console.error("currenttemp:"+t.rate+" lastTempAge:"+gt+"m, tempModulus:"+pt+"m"),je.temp="absolute",je.deliverAt=Fe,d&&t&&a.lastTemp&&t.rate!==a.lastTemp.rate&&gt>10&&t.duration)return je.reason="Warning: currenttemp rate "+t.rate+" != lastTemp rate "+a.lastTemp.rate+" from pumphistory; canceling temp",m.setTempBasal(0,0,i,je,t);if(t&&a.lastTemp&&t.duration>0){var vt=gt-a.lastTemp.duration;if(vt>5&&gt>10)return je.reason="Warning: currenttemp running but lastTemp from pumphistory ended "+vt+"m ago; canceling temp",m.setTempBasal(0,0,i,je,t)}var ft=o(-a.activity*ct*5,2),Bt=o(6*(He-ft));Bt<0&&(Bt=o(6*(Ze-ft)))<0&&(Bt=o(6*(e.long_avgdelta-ft)));var bt=ze,Mt=(bt=a.iob>0?o(ze-a.iob*ct):o(ze-a.iob*Math.min(ct,I)))+Bt;if(void 0===Mt||isNaN(Mt))return je.error="Error: could not calculate eventualBG. Sensitivity: "+ct+" Deviation: "+Bt,je;var _t=function(e,t,a){return o(a+(e-t)/24,1)}(Je,Mt,ft);je={temp:"absolute",bg:ze,tick:We,eventualBG:Mt,insulinReq:0,reservoir:u,deliverAt:Fe,sensitivityRatio,TDD:te,insulin:ae,current_target:Je};var yt=[],xt=[],St=[],Dt=[];yt.push(ze),xt.push(ze),Dt.push(ze),St.push(ze);var wt=function(e,t,a,r,o,i){return t?!e.allowSMB_with_high_temptarget&&e.temptargetSet&&o>100?(console.error("SMB disabled due to high temptarget of "+o),!1):!0===a.bwFound&&!1===e.A52_risk_enable?(console.error("SMB disabled due to Bolus Wizard activity in the last 6 hours."),!1):!0===e.enableSMB_always?(a.bwFound?console.error("Warning: SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled due to enableSMB_always"),!0):!0===e.enableSMB_with_COB&&a.mealCOB?(a.bwCarbs?console.error("Warning: SMB enabled with Bolus Wizard carbs: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled for COB of "+a.mealCOB),!0):!0===e.enableSMB_after_carbs&&a.carbs?(a.bwCarbs?console.error("Warning: SMB enabled with Bolus Wizard carbs: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled for 6h after carb entry"),!0):!0===e.enableSMB_with_temptarget&&e.temptargetSet&&o<100?(a.bwFound?console.error("Warning: SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled for temptarget of "+n(o,e)),!0):!0===e.enableSMB_high_bg&&null!==i&&r>=i?(console.error("Checking BG to see if High for SMB enablement."),console.error("Current BG",r," | High BG ",i),a.bwFound?console.error("Warning: High BG SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard"):console.error("High BG detected. Enabling SMB."),!0):(console.error("SMB disabled (no enableSMB preferences active or no condition satisfied)"),!1):(console.error("SMB disabled (!microBolusAllowed)"),!1)}(i,d,l,ze,Je,Ve);b&&(console.error("SMB disabled (an Override is active with SMBs disabled)"),wt=!1);var Tt=i.enableUAM,Ct=0,Ut=0;Ct=o(He-ft,1);var Gt=o(He-ft,1);csf=ct/j,console.error("profile.sens:"+n(I,i)+", sens:"+n(ct,i)+", CSF:"+o(csf,1));var Ot=o(30*csf*5/60,1);Ct>Ot&&(console.error("Limiting carb impact from "+Ct+" to "+Ot+"mg/dL/5m (30g/h)"),Ct=Ot);var Rt=3;sensitivityRatio&&(Rt/=sensitivityRatio);var At=Rt;if(l.carbs){Rt=Math.max(Rt,l.mealCOB/20);var It=o((new Date(qe).getTime()-l.lastCarbTime)/6e4),jt=(l.carbs-l.mealCOB)/l.carbs;At=o(At=Rt+1.5*It/60,1),console.error("Last carbs "+It+" minutes ago; remainingCATime:"+At+"hours; "+o(100*jt,1)+"% carbs absorbed")}var Ft=Math.max(0,Ct/5*60*At/2)/csf,Pt=90,Et=1;i.remainingCarbsCap&&(Pt=Math.min(90,i.remainingCarbsCap)),i.remainingCarbsFraction&&(Et=Math.min(1,i.remainingCarbsFraction));var qt=1-Et,Wt=Math.max(0,l.mealCOB-Ft-l.carbs*qt),kt=(Wt=Math.min(Pt,Wt))*csf*5/60/(At/2),Lt=o(l.slopeFromMaxDeviation,2),zt=o(l.slopeFromMinDeviation,2),Nt=Math.min(Lt,-zt/3);Ut=0===Ct?0:Math.min(60*At/5/2,Math.max(0,l.mealCOB*csf/Ct)),console.error("Carb Impact:"+Ct+"mg/dL per 5m; CI Duration:"+o(5*Ut/60*2,1)+"hours; remaining CI ("+At/2+"h peak):"+o(kt,1)+"mg/dL per 5m");var Ht,Zt,$t,Jt,Kt,Qt=999,Vt=999,Xt=999,Yt=ze,ea=999,ta=999,aa=999,ra=999,oa=Mt,na=ze,ia=ze,sa=0,la=[],ma=[];try{ht.forEach((function(e){var t=o(-e.activity*ct*5,2),a=o(-e.iobWithZeroTemp.activity*ct*5,2),r=bt,n=Ct*(1-Math.min(1,xt.length/12));if(!0===(oe&&!Se))oa=xt[xt.length-1]+o(-e.activity*(1800/(T*le*Math.log(Math.max(xt[xt.length-1],39)/ye+1)))*5,2)+n,r=Dt[Dt.length-1]+o(-e.iobWithZeroTemp.activity*(1800/(T*le*Math.log(Math.max(Dt[Dt.length-1],39)/ye+1)))*5,2),console.log("Dynamic ISF (Logarithmic Formula) )adjusted predictions for IOB and ZT: IOBpredBG: "+o(oa,2)+" , ZTpredBG: "+o(r,2));else oa=xt[xt.length-1]+t+n,r=Dt[Dt.length-1]+a;var i=Math.max(0,Math.max(0,Ct)*(1-yt.length/Math.max(2*Ut,1))),s=Math.min(yt.length,12*At-yt.length),l=Math.max(0,s/(At/2*12)*kt);i+l,la.push(o(l,0)),ma.push(o(i,0)),COBpredBG=yt[yt.length-1]+t+Math.min(0,n)+i+l;var m=Math.max(0,Gt+St.length*Nt),d=Math.max(0,Gt*(1-St.length/Math.max(36,1))),u=Math.min(m,d);if(u>0&&(sa=o(5*(St.length+1)/60,1)),!0===(oe&&!Se))UAMpredBG=St[St.length-1]+o(-e.activity*(1800/(T*le*Math.log(Math.max(St[St.length-1],39)/ye+1)))*5,2)+Math.min(0,n)+u,console.log("Dynamic ISF (Logarithmic Formula) adjusted prediction for UAM: UAMpredBG: "+o(UAMpredBG,2));else UAMpredBG=St[St.length-1]+t+Math.min(0,n)+u;xt.length<48&&xt.push(oa),yt.length<48&&yt.push(COBpredBG),St.length<48&&St.push(UAMpredBG),Dt.length<48&&Dt.push(r),COBpredBG<ea&&(ea=o(COBpredBG)),UAMpredBG<ta&&(ta=o(UAMpredBG)),oa<aa&&(aa=o(oa)),r<ra&&(ra=o(r));xt.length>18&&oa<Qt&&(Qt=o(oa)),oa>na&&(na=oa),(Ut||kt>0)&&yt.length>18&&COBpredBG<Vt&&(Vt=o(COBpredBG)),(Ut||kt>0)&&COBpredBG>na&&(ia=COBpredBG),Tt&&St.length>12&&UAMpredBG<Xt&&(Xt=o(UAMpredBG)),Tt&&UAMpredBG>na&&UAMpredBG}))}catch(e){console.error("Problem with iobArray.  Optional feature Advanced Meal Assist disabled")}l.mealCOB&&(console.error("predCIs (mg/dL/5m):"+ma.join(" ")),console.error("remainingCIs:      "+la.join(" "))),je.predBGs={},xt.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))}));for(var da=xt.length-1;da>12&&xt[da-1]===xt[da];da--)xt.pop();for(je.predBGs.IOB=xt,$t=o(xt[xt.length-1]),Dt.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))})),da=Dt.length-1;da>6&&!(Dt[da-1]>=Dt[da]||Dt[da]<=Je);da--)Dt.pop();if(je.predBGs.ZT=Dt,o(Dt[Dt.length-1]),l.mealCOB>0&&(Ct>0||kt>0)){for(yt.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))})),da=yt.length-1;da>12&&yt[da-1]===yt[da];da--)yt.pop();je.predBGs.COB=yt,Jt=o(yt[yt.length-1]),Mt=Math.max(Mt,o(yt[yt.length-1]))}if(Ct>0||kt>0){if(Tt){for(St.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))})),da=St.length-1;da>12&&St[da-1]===St[da];da--)St.pop();je.predBGs.UAM=St,Kt=o(St[St.length-1]),St[St.length-1]&&(Mt=Math.max(Mt,o(St[St.length-1])))}je.eventualBG=Mt}console.error("UAM Impact:"+Gt+"mg/dL per 5m; UAM Duration:"+sa+"hours"),Qt=Math.max(39,Qt),Vt=Math.max(39,Vt),Xt=Math.max(39,Xt),Ht=o(Qt);var ua=l.mealCOB/l.carbs;Zt=o(Xt<999&&Vt<999?(1-ua)*UAMpredBG+ua*COBpredBG:Vt<999?(oa+COBpredBG)/2:Xt<999?(oa+UAMpredBG)/2:oa),ra>Zt&&(Zt=ra),Yt=o(Yt=Ut||kt>0?Tt?ua*ea+(1-ua)*ta:ea:Tt?ta:aa);var ca=Xt;if(ra<mt)ca=(Xt+ra)/2;else if(ra<Je){var ga=(ra-mt)/(Je-mt);ca=(Xt+(Xt*ga+ra*(1-ga)))/2}else ra>Xt&&(ca=(Xt+ra)/2);if(ca=o(ca),l.carbs)if(!Tt&&Vt<999)Ht=o(Math.max(Qt,Vt));else if(Vt<999){var ha=ua*Vt+(1-ua)*ca;Ht=o(Math.max(Qt,Vt,ha))}else Ht=Tt?ca:Yt;else Tt&&(Ht=o(Math.max(Qt,ca)));Ht=Math.min(Ht,Zt),process.stderr.write("minPredBG: "+Ht+" minIOBPredBG: "+Qt+" minZTGuardBG: "+ra),Vt<999&&process.stderr.write(" minCOBPredBG: "+Vt),Xt<999&&process.stderr.write(" minUAMPredBG: "+Xt),console.error(" avgPredBG:"+Zt+" COB/Carbs:"+l.mealCOB+"/"+l.carbs),ia>ze&&(Ht=Math.min(Ht,ia)),je.COB=l.mealCOB,je.IOB=a.iob,je.BGI=n(ft,i),je.deviation=n(Bt,i),je.ISF=n(ct,i),je.CR=o(j,1),je.target_bg=n(Je,i),je.TDD=o(te,2),je.current_target=o(Je,0);var pa=je.CR;Ge!=je.CR&&(pa=Ge+"→"+je.CR),je.reason=ut+", COB: "+je.COB+", Dev: "+je.deviation+", BGI: "+je.BGI+", CR: "+pa+", Target: "+ot+", minPredBG "+n(Ht,i)+", minGuardBG "+n(Yt,i)+", IOBpredBG "+n($t,i),Jt>0&&(je.reason+=", COBpredBG "+n(Jt,i)),Kt>0&&(je.reason+=", UAMpredBG "+n(Kt,i)),je.reason+=tddReason,je.reason+="; ";var va=bt;va<40&&(va=Math.min(Yt,va));var fa,Ba=mt-va,ba=240,Ma=240;if(l.mealCOB>0&&(Ct>0||kt>0)){for(da=0;da<yt.length;da++)if(yt[da]<Ke){ba=5*da;break}for(da=0;da<yt.length;da++)if(yt[da]<mt){Ma=5*da;break}}else{for(da=0;da<xt.length;da++)if(xt[da]<Ke){ba=5*da;break}for(da=0;da<xt.length;da++)if(xt[da]<mt){Ma=5*da;break}}wt&&Yt<mt&&(console.error("minGuardBG "+n(Yt,i)+" projected below "+n(mt,i)+" - disabling SMB"),wt=!1),void 0===i.maxDelta_bg_threshold&&(fa=.2),void 0!==i.maxDelta_bg_threshold&&(fa=Math.min(i.maxDelta_bg_threshold,.4)),$e>fa*ze&&(console.error("maxDelta "+n($e,i)+" > "+100*fa+"% of BG "+n(ze,i)+" - disabling SMB"),je.reason+="maxDelta "+n($e,i)+" > "+100*fa+"% of BG "+n(ze,i)+" - SMB disabled!, ",wt=!1),console.error("BG projected to remain above "+n(Ke,i)+" for "+ba+"minutes"),(Ma<240||ba<60)&&console.error("BG projected to remain above "+n(mt,i)+" for "+Ma+"minutes");var _a=Ma,ya=i.current_basal*A*ct*_a/60,xa=Math.max(0,l.mealCOB-.25*l.carbs),Sa=(Ba-ya)/csf-xa;ya=o(ya),Sa=o(Sa),console.error("naive_eventualBG:",bt,"bgUndershoot:",Ba,"zeroTempDuration:",_a,"zeroTempEffect:",ya,"carbsReq:",Sa),"Could not parse clock data"==l.reason?console.error("carbsReq unknown: Could not parse clock data"):Sa>=i.carbsReqThreshold&&Ma<=45&&(je.carbsReq=Sa,je.reason+=Sa+" add'l carbs req w/in "+Ma+"m; ");var Da=0;if(ze<mt&&a.iob<-i.current_basal*A*20/60&&He>0&&He>_t)je.reason+="IOB "+a.iob+" < "+o(-i.current_basal*A*20/60,2),je.reason+=" and minDelta "+n(He,i)+" > expectedDelta "+n(_t,i)+"; ";else if(ze<mt||Yt<mt)return je.reason+="minGuardBG "+n(Yt,i)+"<"+n(mt,i),Da=o(60*((Ba=Je-Yt)/ct)/i.current_basal*A),Da=30*o(Da/30),Da=Math.min(120,Math.max(30,Da)),m.setTempBasal(0,Da,i,je,t);if(i.skip_neutral_temps&&je.deliverAt.getMinutes()>=55)return je.reason+="; Canceling temp at "+je.deliverAt.getMinutes()+"m past the hour. ",m.setTempBasal(0,0,i,je,t);var wa=0,Ta=Ee;if(Mt<Ke){if(je.reason+="Eventual BG "+n(Mt,i)+" < "+n(Ke,i),He>_t&&He>0&&!Sa)return bt<40?(je.reason+=", naive_eventualBG < 40. ",m.setTempBasal(0,30,i,je,t)):(e.delta>He?je.reason+=", but Delta "+n(We,i)+" > expectedDelta "+n(_t,i):je.reason+=", but Min. Delta "+He.toFixed(2)+" > Exp. Delta "+n(_t,i),t.duration>15&&r(Ee,i)===r(t.rate,i)?(je.reason+=", temp "+t.rate+" ~ req "+Ee+"U/hr. ",je):(je.reason+="; setting current basal of "+Ee+" as temp. ",m.setTempBasal(Ee,30,i,je,t)));wa=o(wa=2*Math.min(0,(Mt-Je)/ct),2);var Ca=Math.min(0,(bt-Je)/ct);if(Ca=o(Ca,2),He<0&&He>_t)wa=o(wa*(He/_t),2);if(Ta=r(Ta=Ee+2*wa,i),t.duration*(t.rate-Ee)/60<Math.min(wa,Ca)-.3*Ee)return je.reason+=", "+t.duration+"m@"+t.rate.toFixed(2)+" is a lot less than needed. ",m.setTempBasal(Ta,30,i,je,t);if(void 0!==t.rate&&t.duration>5&&Ta>=.8*t.rate)return je.reason+=", temp "+t.rate+" ~< req "+Ta+"U/hr. ",je;if(Ta<=0){if((Da=o(60*((Ba=Je-bt)/ct)/i.current_basal*A))<0?Da=0:(Da=30*o(Da/30),Da=Math.min(120,Math.max(0,Da))),Da>0)return je.reason+=", setting "+Da+"m zero temp. ",m.setTempBasal(Ta,Da,i,je,t)}else je.reason+=", setting "+Ta+"U/hr. ";return m.setTempBasal(Ta,30,i,je,t)}if(He<_t&&(!d||!wt))return e.delta<He?je.reason+="Eventual BG "+n(Mt,i)+" > "+n(Ke,i)+" but Delta "+n(We,i)+" < Exp. Delta "+n(_t,i):je.reason+="Eventual BG "+n(Mt,i)+" > "+n(Ke,i)+" but Min. Delta "+He.toFixed(2)+" < Exp. Delta "+n(_t,i),t.duration>15&&r(Ee,i)===r(t.rate,i)?(je.reason+=", temp "+t.rate+" ~ req "+Ee+"U/hr. ",je):(je.reason+="; setting current basal of "+Ee+" as temp. ",m.setTempBasal(Ee,30,i,je,t));if(Math.min(Mt,Ht)<Qe&&(!d||!wt))return je.reason+=n(Mt,i)+"-"+n(Ht,i)+" in range: no temp required",t.duration>15&&r(Ee,i)===r(t.rate,i)?(je.reason+=", temp "+t.rate+" ~ req "+Ee+"U/hr. ",je):(je.reason+="; setting current basal of "+Ee+" as temp. ",m.setTempBasal(Ee,30,i,je,t));if(Mt>=Qe&&(je.reason+="Eventual BG "+n(Mt,i)+" >= "+n(Qe,i)+", "),a.iob>Xe)return je.reason+="IOB "+o(a.iob,2)+" > max_iob "+Xe,t.duration>15&&r(Ee,i)===r(t.rate,i)?(je.reason+=", temp "+t.rate+" ~ req "+Ee+"U/hr. ",je):(je.reason+="; setting current basal of "+Ee+" as temp. ",m.setTempBasal(Ee,30,i,je,t));(wa=o((Math.min(Ht,Mt)-Je)/ct,2))>Xe-a.iob?(console.error("SMB limited by maxIOB: "+Xe-a.iob+" (. insulinReq: "+wa+" U)"),je.reason+="max_iob "+Xe+", ",wa=Xe-a.iob):console.error("SMB not limited by maxIOB ( insulinReq: "+wa+" U)."),Ta=r(Ta=Ee+2*wa,i),wa=o(wa,3),je.insulinReq=wa;var Ua=o((new Date(qe).getTime()-a.lastBolusTime)/6e4,1);if(d&&wt&&ze>mt){var Ga=o(l.mealCOB/j,3),Oa=0;void 0===i.maxSMBBasalMinutes?(Oa=o(i.current_basal*A*30/60,1),console.error("profile.maxSMBBasalMinutes undefined: defaulting to 30m"),wa>Oa&&console.error("SMB limited by maxBolus: "+Oa+" ( "+wa+" U)")):a.iob>Ga&&a.iob>0?(console.error("IOB"+a.iob+"> COB"+l.mealCOB+"; mealInsulinReq ="+Ga),i.maxUAMSMBBasalMinutes?(console.error("profile.maxUAMSMBBasalMinutes: "+i.maxUAMSMBBasalMinutes+", profile.current_basal: "+i.current_basal*A),Oa=o(i.current_basal*A*i.maxUAMSMBBasalMinutes/60,1)):(console.error("profile.maxUAMSMBBasalMinutes undefined: defaulting to 30m"),Oa=o(i.current_basal*A*30/60,1)),wa>Oa?console.error("SMB limited by maxUAMSMBBasalMinutes [ "+i.maxUAMSMBBasalMinutes+"m ]: "+Oa+"U ( "+wa+"U )"):console.error("SMB is not limited by maxUAMSMBBasalMinutes. ( insulinReq: "+wa+"U )")):(console.error("profile.maxSMBBasalMinutes: "+i.maxSMBBasalMinutes+", profile.current_basal: "+i.current_basal*A),wa>(Oa=o(i.current_basal*i.maxSMBBasalMinutes/60,1))?console.error("SMB limited by maxSMBBasalMinutes: "+i.maxSMBBasalMinutes+"m ]: "+Oa+"U ( insulinReq: "+wa+"U )"):console.error("SMB is not limited by maxSMBBasalMinutes. ( insulinReq: "+wa+"U )"));var Ra=i.bolus_increment,Aa=1/Ra,Ia=i.smb_delivery_ratio;Ia>.5&&console.error("SMB Delivery Ratio increased from default 0.5 to "+o(Ia,2));var ja=Math.min(wa*Ia,Oa);ja=Math.floor(ja*Aa)/Aa,Da=o(60*((Je-(bt+Qt)/2)/ct)/i.current_basal*A),wa>0&&ja<Ra&&(Da=0);var Fa=0;Da<=0?Da=0:Da>=30?(Da=30*o(Da/30),Da=Math.min(60,Math.max(0,Da))):(Fa=o(Ee*Da/30,2),Da=30),je.reason+=" insulinReq "+wa,ja>=Oa&&(je.reason+="; maxBolus "+Oa),Da>0&&(je.reason+="; setting "+Da+"m low temp of "+Fa+"U/h"),je.reason+=". ";var Pa=3;i.SMBInterval&&(Pa=Math.min(10,Math.max(1,i.SMBInterval)));var Ea=o(Pa-Ua,0),qa=o(60*(Pa-Ua),0)%60;if(console.error("naive_eventualBG "+bt+","+Da+"m "+Fa+"U/h temp needed; last bolus "+Ua+"m ago; maxBolus: "+Oa),Ua>Pa?ja>0&&(je.units=ja,je.reason+="Microbolusing "+ja+"U. "):je.reason+="Waiting "+Ea+"m "+qa+"s to microbolus again. ",Da>0)return je.rate=Fa,je.duration=Da,je}var Wa=m.getMaxSafeBasal(i);return Ta>Wa&&(je.reason+="adj. req. rate: "+Ta+" to maxSafeBasal: "+o(Wa,2)+", ",Ta=r(Wa,i)),t.duration*(t.rate-Ee)/60>=2*wa?(je.reason+=t.duration+"m@"+t.rate.toFixed(2)+" > 2 * insulinReq. Setting temp basal of "+Ta+"U/hr. ",m.setTempBasal(Ta,30,i,je,t)):void 0===t.duration||0===t.duration?(je.reason+="no temp, setting "+Ta+"U/hr. ",m.setTempBasal(Ta,30,i,je,t)):t.duration>5&&r(Ta,i)<=r(t.rate,i)?(je.reason+="temp "+t.rate+" >~ req "+Ta+"U/hr. ",je):(je.reason+="temp "+t.rate+"<"+Ta+"U/hr. ",m.setTempBasal(Ta,30,i,je,t))}},6880:(e,t,a)=>{var r=a(6654);e.exports=function(e,t){var a=20;void 0!==t&&"string"==typeof t.model&&(r(t.model,"54")||r(t.model,"23"))&&(a=40);return e<1?Math.round(e*a)/a:e<10?Math.round(20*e)/20:Math.round(10*e)/10}},2705:(e,t,a)=>{var r=a(5639).Symbol;e.exports=r},9932:e=>{e.exports=function(e,t){for(var a=-1,r=null==e?0:e.length,o=Array(r);++a<r;)o[a]=t(e[a],a,e);return o}},9750:e=>{e.exports=function(e,t,a){return e==e&&(void 0!==a&&(e=e<=a?e:a),void 0!==t&&(e=e>=t?e:t)),e}},4239:(e,t,a)=>{var r=a(2705),o=a(9607),n=a(2333),i=r?r.toStringTag:void 0;e.exports=function(e){return null==e?void 0===e?"[object Undefined]":"[object Null]":i&&i in Object(e)?o(e):n(e)}},531:(e,t,a)=>{var r=a(2705),o=a(9932),n=a(1469),i=a(3448),s=r?r.prototype:void 0,l=s?s.toString:void 0;e.exports=function e(t){if("string"==typeof t)return t;if(n(t))return o(t,e)+"";if(i(t))return l?l.call(t):"";var a=t+"";return"0"==a&&1/t==-Infinity?"-0":a}},7561:(e,t,a)=>{var r=a(7990),o=/^\s+/;e.exports=function(e){return e?e.slice(0,r(e)+1).replace(o,""):e}},1957:(e,t,a)=>{var r="object"==typeof a.g&&a.g&&a.g.Object===Object&&a.g;e.exports=r},9607:(e,t,a)=>{var r=a(2705),o=Object.prototype,n=o.hasOwnProperty,i=o.toString,s=r?r.toStringTag:void 0;e.exports=function(e){var t=n.call(e,s),a=e[s];try{e[s]=void 0;var r=!0}catch(e){}var o=i.call(e);return r&&(t?e[s]=a:delete e[s]),o}},2333:e=>{var t=Object.prototype.toString;e.exports=function(e){return t.call(e)}},5639:(e,t,a)=>{var r=a(1957),o="object"==typeof self&&self&&self.Object===Object&&self,n=r||o||Function("return this")();e.exports=n},7990:e=>{var t=/\s/;e.exports=function(e){for(var a=e.length;a--&&t.test(e.charAt(a)););return a}},6654:(e,t,a)=>{var r=a(9750),o=a(531),n=a(554),i=a(9833);e.exports=function(e,t,a){e=i(e),t=o(t);var s=e.length,l=a=void 0===a?s:r(n(a),0,s);return(a-=t.length)>=0&&e.slice(a,l)==t}},1469:e=>{var t=Array.isArray;e.exports=t},3218:e=>{e.exports=function(e){var t=typeof e;return null!=e&&("object"==t||"function"==t)}},7005:e=>{e.exports=function(e){return null!=e&&"object"==typeof e}},3448:(e,t,a)=>{var r=a(4239),o=a(7005);e.exports=function(e){return"symbol"==typeof e||o(e)&&"[object Symbol]"==r(e)}},8601:(e,t,a)=>{var r=a(4841),o=1/0;e.exports=function(e){return e?(e=r(e))===o||e===-1/0?17976931348623157e292*(e<0?-1:1):e==e?e:0:0===e?e:0}},554:(e,t,a)=>{var r=a(8601);e.exports=function(e){var t=r(e),a=t%1;return t==t?a?t-a:t:0}},4841:(e,t,a)=>{var r=a(7561),o=a(3218),n=a(3448),i=/^[-+]0x[0-9a-f]+$/i,s=/^0b[01]+$/i,l=/^0o[0-7]+$/i,m=parseInt;e.exports=function(e){if("number"==typeof e)return e;if(n(e))return NaN;if(o(e)){var t="function"==typeof e.valueOf?e.valueOf():e;e=o(t)?t+"":t}if("string"!=typeof e)return 0===e?e:+e;e=r(e);var a=s.test(e);return a||l.test(e)?m(e.slice(2),a?2:8):i.test(e)?NaN:+e}},9833:(e,t,a)=>{var r=a(531);e.exports=function(e){return null==e?"":r(e)}}},t={};function a(r){var o=t[r];if(void 0!==o)return o.exports;var n=t[r]={exports:{}};return e[r](n,n.exports,a),n.exports}a.g=function(){if("object"==typeof globalThis)return globalThis;try{return this||new Function("return this")()}catch(e){if("object"==typeof window)return window}}();var r=a(5546);freeaps_determineBasal=r})();