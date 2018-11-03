# README #


### What is this repository for? ###

* A music app on Apple watch controlled by hand gestures
* Ver: 1.0

### Project Plan ###

1. Collect data meets requirement for training.
    1. Test how many iterations should be executed according to the average time to complete a gesture,so that we can get same number of ouput data each time,that means each set of data to represent a gesture has same dimensions,which is required to train the SVM model later in python.
2. Train our own SVM model in python by using our own dataset
3. Convert the trained model to the format supported by CoreML by using a python package named coremltools
4. Use the trained model in watch app to predict future hand gesture
5. Utilized DoubanFM's API to retrieve sound track.

### What's finished ###

1. Apple watch is able to accept 3 gestures to control the music playing-- 'shake to the left' as previous song, 'draw a circle' as play/pause, 'shake to the right' as next song.
2. Accuracy is around 60%, but not stable and needs to be improved by adjusting the parameters in svm algorithm. 
3. Music's playing functions well on IPhone8 plus.


### What's NOT finished ###

1. Currently the hand gesture's recognition needs to be triggered by touching the 'predict' button on apple watch, need a better way to trigger the recognition of gesture.

* Requirements
	* scikit-learn on github
		* Python (>= 2.7 or >= 3.3)
		* NumPy (>= 1.8.2)
		* SciPy (>= 0.13.3)
	* coremltools
		* Python (2.7)
    
### Team Members ###

* Haojian Yang
