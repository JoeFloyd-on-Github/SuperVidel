[SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431649&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431649)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431649&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431649) by [TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Fri Mar 18, 2022 8:06 pm
Well, I am trying to update my SuperVidel (which is sitting on v7) to a newer firmware and since the updating app running on the Falcon from my other thread isn't working, I'm trying to update the SuperVidel via PC using the Xilinx Platform Cable USB and the Impact software.

I was following the guide from here:

https://www.exxoshost.co.uk/atari/last/CT60/flash.htm

which is for the CT60. I didn't see a specific SV guide although on Nature's site there is a blurb under the heading for Update 5
Code: [Select all](https://www.atari-forum.com/viewtopic.php?t=41681#)

```
SuperVidel firmware v005
Updated August 27 2013
SV firmware in MCS-format. For use with Xilinx Impact (WinXP or later or Ubuntu), 
when you have bricked your SV and cannot use SVUPDxxx.APP. 
Follow the instructions manual for updating the ABE+SDR, 
but instead use the 2mm-pitch 14-pin flat cable that comes with
the Xilinx Platform Cable USB to connect to the SV (connector JP2 near the DVI).
Note the key on the cable! And be careful with the chips on the bottom side of
the SV while you press to insert the cable! 
The "..._1.mcs" should be selected for the left icon in Impact and 
the "..._0.mcs" should be selected for the right icon. 
```

So I set up the Xilinx software (which was a pain) and got out my Xilinx cable kit. When I hooked the cable up to the PC and the SV with Impact software running I then turned on the Falcon.

Everything looked ok and it seemed to recognize the chips. However, when I went to load in the first MCS file for the left chip I got the following message:

xilinx_sv_chips.png

Is this normal or is there a problem? Also, does it matter if I am powering on the Falcon in CT60 mode or 030 mode?
You do not have the required permissions to view the files attached to this post.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Fuji Shaped Bastard
Posts: [2717](https://www.atari-forum.com/search.php?author_id=21437&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Mon Jul 23, 2012 8:57 pm
Location: Almost Heaven, West Virginia
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431650&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431650)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431650&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431650) by [TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Fri Mar 18, 2022 8:35 pm
Ok, I couldn't help it. I went ahead and programmed the two chips with v10 of the SV firmware even with the warning.

sv_programming.png

Everything went ok.

1) erase chips
2) blank check chips
3) program chips
4) verify chips

So I powered down the Falcon and removed the JTAG cable. After setting the Falcon back up and booting it, the firmware revision is reported as 000! :lol:

Well, I guess it has to be reprogrammed. Anyone know why the MCS files are being flagged by the Impact software as not being configuration files?
You do not have the required permissions to view the files attached to this post.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[Rustynutt](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=20908&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Atari God
Posts: [1847](https://www.atari-forum.com/search.php?author_id=20908&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Wed Mar 21, 2012 7:38 am
Location: Oregon
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431654&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431654)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431654&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431654) by [Rustynutt](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=20908&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Fri Mar 18, 2022 10:19 pm
Been a while, think recall this. The big deal is getting the file order correct.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Fuji Shaped Bastard
Posts: [2717](https://www.atari-forum.com/search.php?author_id=21437&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Mon Jul 23, 2012 8:57 pm
Location: Almost Heaven, West Virginia
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431655&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431655)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431655&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431655) by [TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Fri Mar 18, 2022 10:32 pm
Do you program the SV in 060 or 030 mode? I hope it is the 060 mode because that is what I was using.

Yeah, I think I may have had the files backward. Now I put the _0 file first in line and it didn't complain this time. For the next chip in line I put the _1 file and it complained but I think that's ok since it is cascaded? So I ended up with this:

sv_programming_b.png

Don't know if it worked yet. It programmed and verified but when I check on the Falcon, it still reported v000. :shrug:
You do not have the required permissions to view the files attached to this post.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Hardware Guru
Posts: [5729](https://www.atari-forum.com/search.php?author_id=2009&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Sat Sep 10, 2005 11:11 am
Location: Brisbane, QLD, Australia
Contact:
[Contact mikro](https://www.atari-forum.com/viewtopic.php?t=41681#)
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431669&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431669)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431669&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431669) by [mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sat Mar 19, 2022 9:21 am
See my MCS flashing advice: [Re: 1920x1080 stopped working](https://www.atari-forum.com/viewtopic.php?p=370890#p370890) :) IIRC I had to actually disconnect SuperVidel from the CT60 (or I read it somewhere and just followed the advice?)
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Fuji Shaped Bastard
Posts: [2717](https://www.atari-forum.com/search.php?author_id=21437&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Mon Jul 23, 2012 8:57 pm
Location: Almost Heaven, West Virginia
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431671&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431671)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431671&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431671) by [TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sat Mar 19, 2022 9:48 am
So the opposite of how I flashed it in the post above yours. :lol:

So the _1 file goes to in device 1 and the _0 file to device 2. Thanks for the confirmation.

[mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) wrote: Sat Mar 19, 2022 9:21 amIIRC I had to actually disconnect SuperVidel from the CT60 (or I read it somewhere and just followed the advice?)

Could you explain this statement a little more for me? You had to flash with the SV disconnected from the CT60?


P.S. Do you remember getting the Impact software warning after loading the MCS files like I showed in the first post here?
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Hardware Guru
Posts: [5729](https://www.atari-forum.com/search.php?author_id=2009&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Sat Sep 10, 2005 11:11 am
Location: Brisbane, QLD, Australia
Contact:
[Contact mikro](https://www.atari-forum.com/viewtopic.php?t=41681#)
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431675&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431675)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431675&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431675) by [mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sat Mar 19, 2022 11:05 am
[TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) wrote: Sat Mar 19, 2022 9:48 amCould you explain this statement a little more for me? You had to flash with the SV disconnected from the CT60?
If my memory serves me well, then yes. But it's possible I was just over-cautious. Or my memory isn't that great.
P.S. Do you remember getting the Impact software warning after loading the MCS files like I showed in the first post here?
I don't, it looks quite scary to be honest. But it does like a cascaded setup actually so perhaps it is correct? Too bad I didn't write a longer post about my flashing experience.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Hardware Guru
Posts: [5729](https://www.atari-forum.com/search.php?author_id=2009&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Sat Sep 10, 2005 11:11 am
Location: Brisbane, QLD, Australia
Contact:
[Contact mikro](https://www.atari-forum.com/viewtopic.php?t=41681#)
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431676&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431676)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431676&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431676) by [mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sat Mar 19, 2022 11:15 am
Btw, some SV updating posts: [Re: FW11 update app](https://www.atari-forum.com/viewtopic.php?p=369936#p369936), [[SOLVED] SV FW 010 -> Crash](https://www.atari-forum.com/viewtopic.php?p=297790#p297790). Interestingly, the latter one seems to imply that it has been flashed in 060 mode, too (via the APP, no mention how it was flashed via Xilinx ISE).
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Fuji Shaped Bastard
Posts: [2717](https://www.atari-forum.com/search.php?author_id=21437&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Mon Jul 23, 2012 8:57 pm
Location: Almost Heaven, West Virginia
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431678&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431678)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431678&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431678) by [TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sat Mar 19, 2022 11:22 am
Yes, thanks, I had read those yesterday. I think I read everything on the sub-forum about it. :lol:

What is confusing me is why is it recommended to flash in 060 mode which means in-circuit with power-on to the Falcon yet you seem to remember flashing the SV out-of-circuit using only the power from the USB programmer cable. Why would the 060 mode be recommended if it can be done OOC which is safer imo.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Fuji Shaped Bastard
Posts: [2717](https://www.atari-forum.com/search.php?author_id=21437&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Mon Jul 23, 2012 8:57 pm
Location: Almost Heaven, West Virginia
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=431685&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431685)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=431685&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p431685) by [TheNameOfTheGame](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=21437&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sat Mar 19, 2022 3:32 pm
Yes, I see the programmer needs reference voltage on the chip to flash, so it has to be powered on hence flashing in 060 mode.

I guess when you programmed OOC, you supplied external voltage somehow.
[Top](https://www.atari-forum.com/viewtopic.php?t=41681#top)
[mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Hardware Guru
Posts: [5729](https://www.atari-forum.com/search.php?author_id=2009&sr=posts&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d)
Joined: Sat Sep 10, 2005 11:11 am
Location: Brisbane, QLD, Australia
Contact:
[Contact mikro](https://www.atari-forum.com/viewtopic.php?t=41681#)
[Re: SuperVidel updating using PC](https://www.atari-forum.com/viewtopic.php?p=443140&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p443140)

* 

[Post](https://www.atari-forum.com/viewtopic.php?p=443140&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d#p443140) by [mikro](https://www.atari-forum.com/memberlist.php?mode=viewprofile&u=2009&sid=84db79ccfbfa7d1bd8d65f00e6a4c96d) » Sun Feb 12, 2023 8:11 pm
Just to follow up on this: as I have flashed the SuperVidel today from scratch, I can remember very well what I did. :)

The warning is there also for me and yes, I also ignored it. *_1.mcs goes to the left chip, *_0.mcs to the right one. I kept the SuperVidel in Falcon and let the machine running for the whole time (I seem to have the same Xilinux Platform Cable USB as you do so I just connected the cable to both sockets).

Btw if you are looking for a pretty painless Xilinx ISE/Impact installation, I wholeheartedly recommend Arch Linux and its "xilinx-ise" + "xilinx-usb-drivers" packages from AUR. I didn't have to do basically anything, just let the installer finish (... what took a while). The only "complicated" thing is that you need two things: 1. The license (has to be requested via the software/from their website) 2. File Xilinx_ISE_DS_Lin_14.7_1015_1.tar (part of Xilinx Linux install, you have to download it from their website).
