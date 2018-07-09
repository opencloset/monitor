import * as React from 'react';

export interface RoomProps { no: number, name: string };

export class Room extends React.Component<RoomProps, {}> {
  constructor(props: RoomProps) {
    super(props);
  }

  render() {
    return <div className="tile is-parent">
      <div className="tile is-child notification is-warning box">
        <p className="subtitle">{this.props.no}</p>
        <p className="title">{this.props.name}</p>
      </div>
    </div>;
  }
}
