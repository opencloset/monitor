import * as React from "react";
import ReconnectingWebSocket from "reconnectingwebsocket";

import axios, { AxiosError, AxiosResponse } from "axios";

import { Room } from "./Room";

import { Alert } from "./Alert";

interface IEventMsgExtra {
  nth: number;
}

interface IEventMsg {
  extra: IEventMsgExtra;
  from: number;
  to: number;
  sender: string;
  order: any;
}

export class Dashboard extends React.Component<{}, any> {
  constructor(props: {}) {
    super(props);
    this.state = { rooms: [], notifications: [] };
  }

  public componentDidMount() {
    this.refreshRooms();

    const hostname = location.hostname;
    const port = location.port;
    const protocol = location.protocol;
    const schema = protocol === "https:" ? "wss:" : "ws:";
    const url = `${schema}//${hostname}:${port}/socket`;
    const ws = new ReconnectingWebSocket(url);
    ws.onopen = (e) => {
      ws.send("/subscribe order");
      ws.send("/subscribe tts");
    };

    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      if (data.sender === "tts" && data.type === 2) {
        const path = data.path;
        const audio1 = new Audio(path[0]);
        const audio2 = new Audio(path[1]);

        // TODO: async await 로 convert
        audio1.addEventListener("ended", () => {
          audio2.play();
        });
        audio1.play();
        return;
      }

      this.refreshRooms();
      this.refreshNotifications(data);
    };

    ws.onerror = (e) => {
      console.log("ws error");
      location.reload();
    };

    ws.onclose = (e) => {
      console.log("ws closed");
    };
  }

  public refreshRooms() {
    axios.get(location.href, { headers: { Accept: "application/json" } })
      .then((res: AxiosResponse) => {
        const data = res.data;
        this.setState({ rooms: data.rooms });
      })
      .catch((err: AxiosError) => {
        console.log(err);
        location.reload();
      })
      .then(() => {
        // always executed
      });
  }

  public refreshNotifications(msg: IEventMsg) {
    const to = msg.to;
    const name = msg.order.user.name;
    const roomNo = to - 19;
    if (roomNo >= 1 && roomNo <= 15) {
      this.setState((prevState: any, props: any) => {
        const noti = prevState.notifications;
        noti.unshift({ no: roomNo, name: name });
        noti.splice(3);
        return { notifications: noti };
      });
    }
  }

  public render() {
    const bottomRooms = [10, 9, 8, 7, 6].map((i) => (
      <Room
        key={i.toString()}
        no={i}
        name={this.state.rooms[i - 1] && this.state.rooms[i - 1].name || ""}
        gender={this.state.rooms[i - 1] && this.state.rooms[i - 1].gender || ""}
      />
    ));

    const leftRooms = [15, 14, 13, 12, 11].map((i) => (
      <Room
        key={i.toString()}
        no={i}
        name={this.state.rooms[i - 1] && this.state.rooms[i - 1].name || ""}
        gender={this.state.rooms[i - 1] && this.state.rooms[i - 1].gender || ""}
      />
    ));

    const rightRooms = [1, 2, 3, 4, 5].map((i) => (
      <Room
        key={i.toString()}
        no={i}
        name={this.state.rooms[i - 1] && this.state.rooms[i - 1].name || ""}
        gender={this.state.rooms[i - 1] && this.state.rooms[i - 1].gender || ""}
      />
    ));

    const alerts = this.state.notifications.map((noti: any, i: number) => (
      <Alert key={i.toString()} title={noti.name + "님 " + noti.no + "번 탈의실"} subtitle="에 의류가 준비되었습니다." />
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
