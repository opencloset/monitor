import * as React from 'react';

export interface AlertProps { header: string; body: string; }

export const Alert = (props: AlertProps) => <article className="message is-large">
  <div className="message-header">
    <p>{props.header}</p>
  </div>
  <div className="message-body">
    {props.body}
  </div>
</article>;
