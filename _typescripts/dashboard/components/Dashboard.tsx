import * as React from 'react';
import { Room } from './Room';
import { Alert } from './Alert';

export interface DashboardProps { }

export const Dashboard = (props: DashboardProps) => <div>
  <div className="tile is-ancestor tile-top">
    <div className="tile is-parent tile-hide">
      <div className="tile is-child box"></div>
    </div>
    <Room no="6" name="" />
    <Room no="7" name="" />
    <Room no="8" name="" />
    <Room no="9" name="" />
    <Room no="10" name="" />
    <div className="tile is-parent tile-hide">
      <div className="tile is-child box"></div>
    </div>
  </div>

  <div className="tile is-ancestor">
    <div className="tile is-2 is-vertical is-parent">
      <Room no="5" name="" />
      <Room no="4" name="" />
      <Room no="3" name="" />
      <Room no="2" name="" />
      <Room no="1" name="" />
    </div>
    <div className="tile is-8 is-parent">
      <div className="tile is-child notification is-danger box box-content">
        <p className="title is-size-1">탈의실 안내</p>
        <p className="subtitle is-size-3">
          탈의실 번호와 이름을 확인한 후 들어가세요.
          도움이 필요하시면 탈의실 내부 벨을 눌러주세요.
        </p>
        <Alert header="안열린님" body="1번 탈의실에 의류가 준비되었습니다." />
      </div>
    </div>
    <div className="tile is-2 is-vertical is-parent">
      <Room no="11" name="" />
      <Room no="12" name="" />
      <Room no="13" name="" />
      <Room no="14" name="" />
      <Room no="15" name="" />
    </div>
  </div>
</div>;
