import * as React from 'react';

export interface RoomProps { no: string; name: string; }

export const Room = (props: RoomProps) => <div className="tile is-parent">
  <div className="tile is-child notification is-warning box">
    <p className="subtitle">{props.no}</p>
    <p className="title">{props.name}</p>
  </div>
</div>;
