# Backend Engineering Intern Assignment

## Objective

- [x] Build custom Docker image of [Gentle](https://github.com/lowerquality/gentle) with [AWS Lambda Python](https://gallery.ecr.aws/lambda/python) as base image.
- [x] Python version >= 3.6 only.
- [x] Test `python3 align.py audio.mp3 words.txt` should run.
- [x] Deploy and test the same on AWS Lambda.
- [x] Document the process.
- [ ] Expose the function endpoint using Flask API. *(Not Possible)*

## Challenges

### Building the application: The application won't build right out of the box

The installation instructions provided in the repository causes build failure. This is because of a few reasons:

- The repository has been inactive for quite a while(*last commit: March 2022*). The submodule [Kaldi](https://github.com/kaldi-asr/kaldi) hasn't been synced with the latest commit, which has a few [patches](https://github.com/lowerquality/gentle/issues/194#issuecomment-414335866).
- `gentle/install.sh` And `gentle/ext/install_kaldi.sh` is skipping dependency check of submodule Kaldi. Therefore, some tools which are package manager dependent are not being installed.
- The dependencies that needed to be installed were dispersed into two files, majorly. `Dockerfile` & `install_deps.sh`. If the base OS was changed, then the package-manager needed to be changed in the two files as well.

#### Solution: Building a custom Script

To solve these issues for macOS and other Linux distributions in general: A custom bash script has been written.

- It installs, checks, and installs (if any are missing) all the required dependencies to build the submodule and the Gentle.
- It fails the build if the required dependencies are not met in early stages.
  - Furthermore, it is critical to be done in the early stages because, it is found that after the build is complete successfully, the execution fails due to some missing tools.
- Duplicate dependencies were merged into the `Dockerfile` in alphabetic order. Therefore, changing from `apt-get` to `yum` is simplified.

### Building the container: The AWS Lambda Python image and dependency incompatibility

The assignment specifies to use [Lambda Python](https://gallery.ecr.aws/lambda/python) from the AWS ECR gallery. Every Lambda image uses [Amazon Linux](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html) and `ffmpeg` which is used by Gentle to convert mp3 to WAV format, is not present in Amazon Linux's repository.

#### Solution 1: Install ffmpeg manually

Some scripts were added to the `Dockerfile` which installs `ffmpeg` and moves it to `/usr/local/bin/`. Also, in a [PR #240](https://github.com/lowerquality/gentle/pull/240) a fix was added to use `sox` a tool similar to `ffmpeg` but the application still crashes.

I tried removing the option of `ffmpeg` altogether, but the result would be same. To solve this dependency issue:

#### Solution 2: Choose a package manager which installs all the dependencies

Due to the above incompatibility, I moved to [python](https://hub.docker.com/_/python) as my base image. I was able to build the application successfully with 0 dependency issues.

To make this image compatible with AWS Lambda container runtime, AWS provides a [runtime interface client](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html). It converts any container into a Lambda-compatible container which could be executed as a Lambda function.

### Long building hours

Building the container image was one of the most time-consuming tasks in the whole assignment. Each build took upwards of 4 hours. If the build fails in the middle due to a dependency issue, we would have to restart the build. A few major problems here were:

- A single job build takes 4.5 hours.
- The order of `Dockerfile` layers in the original file was ineffective in using the build cache.
- The server which was being used to download the language model for Gentle was very slow.

#### Solution: Using make flags

Using `make` flags, like `make -j 10` made the process significantly faster.

- **Parallel Jobs Multi Core Time:** 63 mins (Almost 1 Hour)
- **Linear Job Single Core Time:** 272 mins (Almost 4.5 Hours)

*These results are subjective to the compute machines being used.*

#### Solution: Using Docker cache effectively

After testing different orders of build layers, the new `Dockerfile` uses the build cache effectively and saves time.
[Original](https://github.com/lowerquality/gentle/blob/master/Dockerfile) VS [Updated](https://github.com/JammUtkarsh/gentle/blob/master/Dockerfile.LamdaScript)

#### Solution: Downloading common files

After downloading the language model once, it was reused for every build

### Large image size

A successful build would result in an image as large as 44 GB. While Lambda supports images up to 10 GB in size. ([ref](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)). It is also not possible to use multi-stage builds and transfer content from the *builder stage* to the *production stage* since there are many system tools that were being used.

#### Solution: Removing unnecessary cache, building artifacts and data

A few obvious items that were removed are:

- Package manager cache
- object files

After the build was complete, there was also no need for `gentle/ext/kaldi`, this reduced the size of the image significantly.

Overall, the size was reduced from 44 GB → 14 GB → 8 GB. Also, the use of `Python-slim` image instead of `Python`, saved another 800 MB.

### Testing the built image

A major task after a successful build was to test the image. Due to its large size, it was not feasible to test images on AWS Lambda. It required a tremendous amount of bandwidth and time.

#### Solution: Use the AWS runtime emulator

Optionally, AWS provides a [runtime emulator](https://docs.aws.amazon.com/lambda/latest/dg/images-test.html) which can be installed inside the container and could test locally. Saving a lot of bandwidth and time.

### Running on AWS Lambda: Multi-core application not supported

Gentle uses multiple cores to process data. While running locally, I never faced any issues in running gently because I had access to ample RAM and CPU at my disposal. While Lambda is limited to just one core ([ref](https://docs.aws.amazon.com/lambda/latest/dg/configuration-function-common.html)).

I am attaching a video that shows the CPU of gentle locally: [video](https://drive.google.com/file/d/1hcMS4UmerfE1icFD6NhrGMm1LmiLugeB/view?usp=share_link)
While running the Lambda function on AWS, an error was thrown:

```bash
START RequestId: fcb5dca1-a3c9-49ae-aa76-002faeca2af4 Version: $LATEST
INFO:root:converting audio to 8K sampled wav
INFO:root:starting alignment
Traceback (most recent call last):
File "/gentle/align.py", line 55, in <module>
result = aligner.transcribe(wavfile, progress_cb=on_progress, logging=logging)
File "/gentle/gentle/forced_aligner.py", line 23, in transcribe
words, duration = self.mtt.transcribe(wavfile, progress_cb=progress_cb)
File "/gentle/gentle/transcriber.py", line 50, in transcribe
pool = Pool(min(n_chunks, self.nthreads))
File "/usr/local/lib/python3.9/multiprocessing/pool.py", line 927, in __init__
Pool.__init__(self, processes, initializer, initargs)
File "/usr/local/lib/python3.9/multiprocessing/pool.py", line 196, in __init__
self._change_notifier = self._ctx.SimpleQueue()
File "/usr/local/lib/python3.9/multiprocessing/context.py", line 113, in SimpleQueue
return SimpleQueue(ctx=self.get_context())
File "/usr/local/lib/python3.9/multiprocessing/queues.py", line 341, in __init__
self._rlock = ctx.Lock()
File "/usr/local/lib/python3.9/multiprocessing/context.py", line 68, in Lock
return Lock(ctx=self.get_context())
File "/usr/local/lib/python3.9/multiprocessing/synchronize.py", line 162, in __init__
SemLock.__init__(self, SEMAPHORE, 1, 1, ctx=ctx)
File "/usr/local/lib/python3.9/multiprocessing/synchronize.py", line 57, in __init__
sl = self._semlock = _multiprocessing.SemLock(
OSError: [Errno 38] Function not implemented
END RequestId: fcb5dca1-a3c9-49ae-aa76-002faeca2af4
REPORT RequestId: fcb5dca1-a3c9-49ae-aa76-002faeca2af4 Duration: 3180.86 ms Billed Duration: 3816 ms Memory Size: 3008 MB Max Memory Used: 705 MB Init Duration: 634.42 ms
```

Here are a few more links that I found to investigate the issue:

- [Stack overflow](https://stackoverflow.com/questions/34005930/multiprocessing-semlock-is-not-implemented-when-running-on-aws-lambda)
- [GitHub](https://github.com/joblib/joblib/issues/391)
- [AWS Blog](https://aws.amazon.com/blogs/compute/parallel-processing-in-python-with-aws-lambda/)

#### Solution: Use AWS Fargate

- The goal of the engineering team is to go serverless. Clearly, AWS Lambda is not an option to run Gentle.
- Fargate which is a serverless computational service. The Gentle container could be executed here as it [supports configuration](https://aws.amazon.com/fargate/pricing/#:~:text=Supported%20Configurations) of multicore CPU and enough RAM

## Conclusion

I think that if we are so keen on using Gentle as a service then we can use AWS Fargate to host it. We can also integrate it using AWS Lambda in the form of a trigger to achieve our goal.
