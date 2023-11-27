
Wave :: struct
{
	arr : [3]EntityProps;
};

Night :: struct
{
	waves : [3]Wave;
};

//Night 0
N0W0 :: Wave.{arr=.[.gobby, 0, 0]};
N0W1 :: Wave.{arr=.[.gobby, .gobby, 0]};
N0W2 :: Wave.{arr=.[.gobby, .gobby, .gobby]};

N0 :: Night.{waves=.[N0W0, N0W1, N0W2]};

//All  Nights
WAVES :: Night.[N0, N0, N0];

