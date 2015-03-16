DROP TABLE IF EXISTS `history`;

-- 탈의실 사용 이력을 저장
CREATE TABLE `history` (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    room_no    INTEGER,
    order_id   INTEGER,
    created_at TEXT
);
