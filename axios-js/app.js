import axios from 'axios';

const BASE_URL = 'http://localhost:8010/proxy';

const getTemps = async () => {
  try {
    const res = await axios.get(`${BASE_URL}/cloud/ckkj48532004j8muj3jor22rl/temperature_store/temperatures`);

    const temps = res.data;

    console.log(`GET: Here's the list of temps`, temps);

    return temps;
  } catch (e) {
    console.error(e);
  }
};

const getProfile = async () => {
  try {
    const res = await axios.get(`${BASE_URL}/cloud/ckkj48532004j8muj3jor22rl/sensor_profile/getProfile`);

    const prof = res.data;

    console.log(`GET: Here's the list of temps`, prof);

    return prof;
  } catch (e) {
    console.error(e);
  }
};

const getViolations = async () => {
  try {
    const res = await axios.get(`${BASE_URL}/cloud/ckkj48532004j8muj3jor22rl/temperature_store/threshold_violations`);

    const temps = res.data;

    console.log(`GET: Here's the list of violations`, temps);

    return temps;
  } catch (e) {
    console.error(e);
  }
};

const createLi = item => {
  console.log(Object.values(item)[0])
  const li = document.createElement('li');

  li.appendChild(document.createTextNode(item["temperature"] + " " + item["timestamp"]));

  return li;
};

const addTempsToDOM = temps => {
  const ul = document.getElementById('ulT');
    
  // Add current temp to the top
  const h3 = document.getElementById('cTemp')
  if (h3 != null){
    h3.appendChild(document.createTextNode(Object.values(temps)[0]["temperature"]))
          // Add recent temps
    var i;
    for(i = 1; i < Object.values(temps).length; ++i){
        ul.appendChild(createLi(Object.values(temps)[i]));
    }
  }
    
};

const addProileToDOM = profile => {
    document.getElementById("nameH").firstChild.nodeValue="Sensor Name: " + profile["s_name"]
    document.getElementById("locH").firstChild.nodeValue="Sensor Location: " + profile["location"]
    document.getElementById("thrH").firstChild.nodeValue="Threshold Temperature: " + profile["threshold_temp"]
    document.getElementById("smsH").firstChild.nodeValue="Contact Number: " + profile["sms_num"]
}


const addViolationsToDOM = temps => {
  const ul = document.getElementById('ulV');
    
    // Add recent temps
    if(ul != null){
        var i;
        for(i = 0; i < Object.values(temps).length; ++i){
            ul.appendChild(createLi(Object.values(temps)[i]));
        }
    }
};

const main = async () => {
  addTempsToDOM(await getTemps());
  addViolationsToDOM(await getViolations());
  addProileToDOM(await getProfile());
};

main();

const form = document.querySelector('form');

const formEvent = form.addEventListener('submit', async event => {
  event.preventDefault();

  const s_name = document.getElementById('#new-prof__sname').value;
  const location = document.getElementById('#new-prof__loc').value;
  const threshold_temp = document.getElementById('#new-prof__tt').value;
  const sms_num = document.getElementById('#new-prof__sms').value;

  const prof = {
    s_name,
    location,
    threshold_temp,
    sms_num
  };

  const updatedProfile = await addProf(prof);
  addProileToDOM(await getProfile());
});

export const addProf = async prof => {
  try {
    const res = await axios.post(`${BASE_URL}/event/ckkj48532004j8muj3jor22rl/asp/sensor/profile_updates`, prof);
    const addedProf = res.data;

    console.log(`updated the profile!!`, addedProf);

    return addedProf;
  } catch (e) {
    console.error(e);
  }
};