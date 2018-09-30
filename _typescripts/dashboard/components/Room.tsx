import * as React from "react";

export interface IRoomProps { no: number; name: string; gender: string; }

export class Room extends React.Component<IRoomProps, {}> {
  constructor(props: IRoomProps) {
    super(props);
  }

  public render() {
    let tileColor: string;
    switch (this.props.gender) {
      case "male": {
        tileColor = "is-warning";
        break;
      }
      case "female": {
        tileColor = "is-warning";
        break;
      }
      default: {
        tileColor = "";
        break;
      }
    }

    return <div className="tile is-parent">
      <div className={"tile is-child notification box " + tileColor}>
        <p className="subtitle is-size-2">{this.props.no}</p>
        <p className="title is-size-2">{this.props.name.substring(0, 3)}</p>
      </div>
    </div>;
  }
}
