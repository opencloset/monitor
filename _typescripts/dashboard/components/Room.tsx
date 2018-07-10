import * as React from 'react';

export interface RoomProps { no: number, name: string, gender: string };

export class Room extends React.Component<RoomProps, {}> {
  constructor(props: RoomProps) {
    super(props);
  }

  render() {
    let tileColor: string;
    switch (this.props.gender) {
      case 'male': {
        tileColor = 'is-info';
        break;
      }
      case 'female': {
        tileColor = 'is-danger';
        break;
      }
      default: {
        tileColor = 'is-warning';
        break;
      }
    }

    return <div className="tile is-parent">
      <div className={"tile is-child notification box " + tileColor}>
        <p className="subtitle">{this.props.no}</p>
        <p className="title">{this.props.name}</p>
      </div>
    </div>;
  }
}
