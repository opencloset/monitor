package OpenCloset::Monitor::Status;
use utf8;

our $STATUS_REPAIR        = 6;
our $STATUS_VISIT         = 13;
our $STATUS_MEASURE       = 16;
our $STATUS_SELECT        = 17;
our $STATUS_BOXING        = 18;
our $STATUS_PAYMENT       = 19;
our $STATUS_BOXED         = 44;
our $STATUS_DO_NOT_RENTAL = 40;

our $STATUS_FITTING_ROOM1  = 20;
our $STATUS_FITTING_ROOM2  = 21;
our $STATUS_FITTING_ROOM3  = 22;
our $STATUS_FITTING_ROOM4  = 23;
our $STATUS_FITTING_ROOM5  = 24;
our $STATUS_FITTING_ROOM6  = 25;
our $STATUS_FITTING_ROOM7  = 26;
our $STATUS_FITTING_ROOM8  = 27;
our $STATUS_FITTING_ROOM9  = 28;
our $STATUS_FITTING_ROOM10 = 29;
our $STATUS_FITTING_ROOM11 = 30;

our @ACTIVE_STATUS = (
    $STATUS_REPAIR,  $STATUS_VISIT,
    $STATUS_MEASURE, $STATUS_SELECT,
    $STATUS_BOXING,  $STATUS_PAYMENT,
    $STATUS_BOXED,   $STATUS_FITTING_ROOM1 .. $STATUS_FITTING_ROOM11
);

our %MAP = (
    $STATUS_REPAIR         => '수선',
    $STATUS_VISIT          => '방문',
    $STATUS_MEASURE        => '치수측정',
    $STATUS_SELECT         => '의류선택',
    $STATUS_BOXING         => '포장',
    $STATUS_BOXED          => '포장완료',
    $STATUS_PAYMENT        => '결제대기',
    $STATUS_DO_NOT_RENTAL  => '대여안함',
    $STATUS_FITTING_ROOM1  => '탈의01',
    $STATUS_FITTING_ROOM2  => '탈의02',
    $STATUS_FITTING_ROOM3  => '탈의03',
    $STATUS_FITTING_ROOM4  => '탈의04',
    $STATUS_FITTING_ROOM5  => '탈의05',
    $STATUS_FITTING_ROOM6  => '탈의06',
    $STATUS_FITTING_ROOM7  => '탈의07',
    $STATUS_FITTING_ROOM8  => '탈의08',
    $STATUS_FITTING_ROOM9  => '탈의09',
    $STATUS_FITTING_ROOM10 => '탈의10',
    $STATUS_FITTING_ROOM11 => '탈의11'
);

our %ORDER_MAP = (
    $STATUS_VISIT          => 1,
    $STATUS_MEASURE        => 2,
    $STATUS_SELECT         => 3,
    $STATUS_FITTING_ROOM1  => 4,
    $STATUS_FITTING_ROOM2  => 4,
    $STATUS_FITTING_ROOM3  => 4,
    $STATUS_FITTING_ROOM4  => 4,
    $STATUS_FITTING_ROOM5  => 4,
    $STATUS_FITTING_ROOM6  => 4,
    $STATUS_FITTING_ROOM7  => 4,
    $STATUS_FITTING_ROOM8  => 4,
    $STATUS_FITTING_ROOM9  => 4,
    $STATUS_FITTING_ROOM10 => 4,
    $STATUS_FITTING_ROOM11 => 4,
    $STATUS_REPAIR         => 5,
    $STATUS_BOXING         => 6,
    $STATUS_BOXED          => 6,
    $STATUS_PAYMENT        => 7,
);

our %REVERSE_ORDER_MAP = (
    '방문'       => 1,
    '치수측정' => 2,
    '의류선택' => 3,
    '탈의01'     => 4,
    '탈의02'     => 4,
    '탈의03'     => 4,
    '탈의04'     => 4,
    '탈의05'     => 4,
    '탈의06'     => 4,
    '탈의07'     => 4,
    '탈의08'     => 4,
    '탈의09'     => 4,
    '탈의10'     => 4,
    '탈의11'     => 4,
    '수선'       => 5,
    '포장'       => 6,
    '포장완료' => 6,
    '결제대기' => 7,
);

1;
