import * as React from 'react';
import ReconnectingWebSocket from 'reconnectingwebsocket';
import axios, { AxiosResponse, AxiosError } from 'axios';

import { Room } from './Room';
import { Alert } from './Alert';

export interface DashboardProps { }

interface EventMsgExtra {
  nth: number
}

interface EventMsg {
  extra: EventMsgExtra,
  from: number,
  to: number,
  sender: string,
  order: any
}

export class Dashboard extends React.Component<DashboardProps, any> {
  constructor(props: DashboardProps) {
    super(props);
    this.state = { rooms: [], notifications: [] };
  }

  componentDidMount() {
    this.refreshRooms();

    const hostname = location.hostname;
    const port = location.port;
    const protocol = location.protocol;
    const schema = protocol === 'https:' ? 'wss:' : 'ws:';
    const url = `${schema}//${hostname}:${port}/socket`;
    const ws = new ReconnectingWebSocket(url);
    ws.onopen = (e) => {
      ws.send('/subscribe order');
    }

    ws.onmessage = (e) => {
      let data = JSON.parse(e.data);
      this.refreshRooms();
      this.refreshNotifications(data);
    }

    ws.onerror = (e) => {
      console.log('ws error');
      location.reload();
    }

    ws.onclose = (e) => {
      console.log('ws closed');
    }
  }

  refreshRooms() {
    axios.get(location.href, { headers: { Accept: 'application/json' } })
      .then((res: AxiosResponse) => {
        let data = res.data;
        this.setState({ rooms: data.rooms });
      })
      .catch(function (err: AxiosError) {
        console.log(err);
        location.reload();
      })
      .then(function () {
        // always executed
      })
  }

  refreshNotifications(msg: EventMsg) {
    let to = msg.to;
    let name = msg.order.user.name;
    let room_no = to - 19;
    if (room_no >= 1 && room_no <= 15) {
      this.setState((prevState: any, props: any) => {
        let noti = prevState.notifications;
        noti.unshift({ no: room_no, name: name })
        noti.splice(3);
        return { notifications: noti };
      });
    }
  }

  render() {
    const bottomRooms = [10, 9, 8, 7, 6].map(i => (
      <Room
        key={i.toString()}
        no={i}
        name={this.state.rooms[i - 1] && this.state.rooms[i - 1].name || ''}
        gender={this.state.rooms[i - 1] && this.state.rooms[i - 1].gender || ''}
      />
    ));

    const leftRooms = [15, 14, 13, 12, 11].map(i => (
      <Room
        key={i.toString()}
        no={i}
        name={this.state.rooms[i - 1] && this.state.rooms[i - 1].name || ''}
        gender={this.state.rooms[i - 1] && this.state.rooms[i - 1].gender || ''}
      />
    ));

    const rightRooms = [1, 2, 3, 4, 5].map(i => (
      <Room
        key={i.toString()}
        no={i}
        name={this.state.rooms[i - 1] && this.state.rooms[i - 1].name || ''}
        gender={this.state.rooms[i - 1] && this.state.rooms[i - 1].gender || ''}
      />
    ));

    const alerts = this.state.notifications.map((noti: any, i: number) => (
      <Alert key={i.toString()} title={noti.name + '님 ' + noti.no + '번 탈의실'} subtitle="에 의류가 준비되었습니다." />
    ));

    return <div>
      <div className="tile is-ancestor">
        <div className="tile is-2 is-vertical is-parent">
          {leftRooms}
        </div>
        <div className="tile is-8 is-parent">
          <div className="tile is-child notification box box-content has-background-black">
            <p className="title is-size-1 has-text-warning">탈의실 안내</p>
            <p className="subtitle is-size-3 has-text-white">
              탈의실 번호와 이름을 확인한 후 들어가세요.<br />
              도움이 필요하시면 탈의실 내부 벨을 눌러주세요.
            </p>
            {alerts}
          </div>
        </div>
        <div className="tile is-2 is-vertical is-parent">
          {rightRooms}
        </div>
      </div>

      <div className="tile is-ancestor tile-bottom">
        <div className="tile is-parent tile-hide">
          <div className="tile is-child box"></div>
        </div>
        {bottomRooms}
        <div className="tile is-parent tile-hide">
          <div className="tile is-child box"></div>
        </div>
      </div>
    </div>;
  }
}
