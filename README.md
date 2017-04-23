# NHL.DL
A script for downloading and re-assembling NHL.tv video streams. Won't help you
watch NHL streams live.

*NOTE: THIS SCRIPT REQUIRES AN NHL.TV ACCOUNT, OR AT THE VERY LEAST ACCESS TO THE KEYFILES USED TO DECRYPT STREAMS THAT YOU CAN ONLY GET IF YOU HAVE AN ACCOUNT.*

## Message to NHL.tv
Hi, my name's Casey and I'm a hockey fan who lives in Australia. With the
recent change in your stream delivery infrastructure, it's made it basically
impossible for me to watch games. I use a Linux home theatre PC, and the flash
player doesn't work on it. Also, despite the fact that I have a reasonably ok
internet connection (for Australia, anyway) the medium quality stream still
lags horribly. I'm not sure what changed here, because it worked fine on GCL.
I tend to watch the Habs SportsNet streams - do you put them in Canadian CDNs
or something? The US streams seem less laggy, but maybe it's a coincidence.
Anyway this script is utterly useless for watching live games, and really only
interesting for expats with an NHL.tv account but bad internet, who want to have
the game waiting for them when they wake up... or get home from work.

## Usage:
```bash
$ ./nhldl.sh <master_m3u8_url> <quality>
```

## Example:
```bash
$ ./nhldl.sh "http://hlslive-l3c.med2.med.nhl.com/ls04/nhl/2016/02/10/NHL_GAME_VIDEO_TBLMTL_M2_HOME_20160210/master_wired_web.m3u8" 2500
```

## Requirements:
* An NHL.tv account, or access to the keyfiles on NHL servers.
* Mac or Linux. Sorry Windows users! You could maybe run it through Cygwin?
* The url for the master m3u8 stream file you want to download.
* A copy of ffmpeg, or avconv? I can't keep up with that project.

## How do I find the m3u8 file?
Open the developer tools / inspector in your browser, and watch an nhl.tv
stream. On the network tab, enter 'm3u8' into the filter. Click on the file
called something like `master_wired_web.m3u8` for the URL.

## How do I find the cookies.txt file?
You'll need to export your cookies from your browser to a file called
`cookies.txt` in the same directory as this script. The easiest way to do this
is to use a cookies exporter plugin like [cookies.txt](https://chrome.google.com/webstore/detail/cookiestxt/njabckikapfpffapmjgojcnbfjonfjfg)
for Chrome. Once you've logged in and started playing a stream, click on the
cookie icon in the top right corner of your screen and copy the `mediaAuth_v2`
and `Authorization` lines into the `cookies.txt` file.

If someone wants to figure out how the bloody hell nhl.tv's auth works, we
could scrape the login process and add user/pass to the script arguments. Submit
a PR! :D
