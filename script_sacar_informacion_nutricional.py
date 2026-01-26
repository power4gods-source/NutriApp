haz un sccript que acceda a esta pagina y haga webscrapping:
https://www.bedca.net/bdpub/index.php

con la informacion de cada alimento, lo registrara en un json, siguiendo un formato como:
{
  "food_id": "food_001",
  "name": "pollo",
  "name_variations": ["pollo", "pollo cocido", "pechuga de pollo", "pollo asado"],
  "category": "proteína",
  "nutrition_per_100g": {
    "calories": 195,
    "protein": 29.6,
    "carbohydrates": 0.0,
    "fat": 7.7,
    "fiber": 0.0,
    "sugar": 0.0,
    "sodium": 98.0
  },
  "default_unit": "gramos",
  "unit_conversions": { "gramos": 1.0, "unidades": 150.0 }
},


al inspeccionar elemento, debe acceder a esta direccion JS para que cambie a consulta en la misma pestaña:
document.querySelector("#navigation > div:nth-child(4) > a")
elemento:
<a href="javascript:void(0)" onclick="if (loading == 0){document.getElementById('alphabet').style.display = 'none';loadContent('query.html',new Array())}">Consulta</a>


luego tiene que acceder a este JS path:
document.querySelector("#Alfabetica > span")
elemento:
<span style="color:#002577">Lista alfabética</span>

abrira un listado de alimentos, y tiene que recorrer cada uno de ellos, y obtener la informacion de cada uno, y guardarla en el json.
para cada alimento, debe acceder al link. ejemplo:
<a href="javascript:void(0)" onclick="scroll(0,0);document.getElementById(&quot;alphabet&quot;).style.display = 'none';document.getElementById('previous2').innerHTML = document.getElementById('content2').innerHTML;query(2,new Array('f_id','f_ori_name','f_eng_name','sci_name','langual','foodexcode','mainlevelcode','codlevel1','namelevel1','codsublevel','codlevel2','namelevel2','f_des_esp','f_des_ing','photo','edible_portion','f_origen','c_id','c_ori_name','c_eng_name','eur_name','componentgroup_id','glos_esp','glos_ing','cg_descripcion','cg_description','best_location','v_unit','moex','stdv','min','max','v_n','u_id','u_descripcion','u_description','value_type','vt_descripcion','vt_description','mu_id','mu_descripcion','mu_description','ref_id','citation','at_descripcion','at_description','pt_descripcion','pt_description','method_id','mt_descripcion','mt_description','m_descripcion','m_description','m_nom_esp','m_nom_ing','mhd_descripcion','mhd_description'),new Array('f_id','publico'),new Array('EQUAL','EQUAL'),new Array(),new Array('746',1),'componentgroup_id','ASC')">Aceite de algodón</a>

en la nueva pestaña, se abrira la informacion nutricional. 
debe coger el foodname:<h4 xmlns="http://www.w3.org/1999/xhtml" id="foodname" style="background:#9EC9F8" align="center">Aceite de algodón</h4>
