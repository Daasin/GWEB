import React from 'react';
import {Fieldset} from "primereact/fieldset";
import Contact from './contactRenderer';

export default user => {
   return (
      <div>
         <Fieldset legend="Contact">
            <Contact {...user} />
         </Fieldset>        
      </div>
   );
};