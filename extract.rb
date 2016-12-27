#!/usr/bin/env ruby
require 'yaml'

if(ARGV.length < 3)
  puts "Requires 3 ARGV, src-cf.yml result.yml version "
  exit(1)
end
src=ARGV[0]; #original cf.yml
result=ARGV[1]; 
vversion=ARGV[2];

def getEle(arr, name)
  for item in arr
    if(item['name'] == name)
      return item
    end
  end
  puts "element "+name.to_s+" not found, exit"
  exit 1
end

def updatePropertyReference(pr)
  if(! pr.nil?)
    if( ! pr['property_reference'].nil? )
      pr['property_reference']=pr['property_reference'].gsub(/(\"?\(\( *)(\.)(.+\)\))/, "\\1..cf\\2\\3")
      pr['property_reference']=pr['property_reference'].gsub(/(\"? *)(\.)(.+)/, "\\1..cf\\2\\3")
    end
  end
end

def updateJobProperties(item)
  item['manifest']=item['manifest'].gsub(/(\"?\(\( *)(\.)(.+\)\))/, "\\1..cf\\2\\3").gsub(/(- cflinuxfs2)(:.+)/,"- \(\( stack.value \)\)\\2")
  item['manifest']=item['manifest'].gsub(/(\"?\(\( *)(\.\.cf\.ha_proxy)(.+\)\))/, "\\1.ha_proxy"+deploymentName()+ "\\3")
  item['manifest']=item['manifest'].gsub(/(\"?\(\( *)(\.\.cf\.router)(.+\)\))/, "\\1.router"+deploymentName()+ "\\3")
  item['manifest']=item['manifest'].gsub(/(\"?\(\( *)(\.\.cf\.diego_cell)(.+\)\))/, "\\1.diego_cell"+deploymentName()+ "\\3")
  item['name']=item['name']+deploymentName
  item['instance_definition'].delete('zero_if')
  # updatePropertyReference(item['instance_definition']['zero_if'])
  item
end

def addKeepalivedProperties(item)
  item['manifest']=item['manifest'].gsub(/( *ha_proxy\: *)/, "keepalived\:\n  vip\: \(\( keepalived_vip.value \)\)\n  virtual_router_id\: \(\( keepalived_virtual_router_id.value \)\)\n\\1")
  item['templates'].push({'name'=>'keepalived','release'=>'haproxy'})
  item['property_blueprints'].push({"configurable"=>true,"name"=>"keepalived_vip","optional"=>false,"type"=>"string"})
  item['property_blueprints'].push({"configurable"=>true,"name"=>"keepalived_virtual_router_id","optional"=>true,"type"=>"integer"})
  item
end

def deploymentName()
  "__name__"
end
# item['property_blueprints']
def getConfigurable(arr)
  result=[]
  for item in arr
    if (item['configurable'])
      result.push(item['name'])
    end
  end
  return result
end

def addPrefix(prefix, arr)
  result = []
  for item in arr
      result.push(prefix+item)
  end
  return result
end


def updateForm(form, keys)
  inputs = form['property_inputs']
  resultInputs =[]
  for input in inputs
    for key in keys
      if input['reference'] == key
        input['reference']=input['reference'].gsub( /( *\.)([^\.]*)(.*)/,"\\1\\2"+deploymentName+"\\3" )
        resultInputs.push input
        break
      end
    end
  end
  if(resultInputs.length > 0 )
    form['property_inputs'] = resultInputs
    return form
  else
    return nil
  end
end

def updateForms(forms,keys)
  resultForms=[]
  for form in forms
    frm = updateForm(form,keys);
    if !frm.nil?
      resultForms.push frm
    end
  end
  return resultForms
end

# - configurable: true
# default: 10.254.0.0/22
# name: garden_network_pool
# optional: false
# type: string

def addProperty(job)
  job['property_blueprints'].push({"configurable"=>true,"name"=>"stack","optional"=>false,"type"=>"string"})
  return job
end


def addKeepalivedInputs(forms)
  return forms
end


# - description:
#   label: Networking
#   name: networking
#   property_inputs:
#   - description:
#     label: Router IPs
#     reference: ".routecr.static_ips"

def addInputs(forms)
  forms.push( {"description"=>"Config",
               "label"=>"Config","name"=>"config",
               "property_inputs"=>[{"description"=>"Stack","label"=>"Stack","reference"=>".diego_cell"+deploymentName+".stack"},
                                   {"description"=>"Virtual IP","label"=>"Virtual IP","reference"=>".ha_proxy"+deploymentName+".keepalived_vip"},
                                   {"description"=>"Same Keepalived group share same virtual router ID ","label"=>"Virtual Router ID","reference"=>".ha_proxy"+deploymentName+".keepalived_virtual_router_id"}]  });
end

def printKey(obj)
  for v,i in obj
    puts v
  end
  exit 1 #log will trigger exit
end

def dependsReleases(job)
  # puts "depdnes releases:: "+job['templates'].to_s
  job['templates'].map {|ele| ele['release']}
end

def commProp(jobNmae)
  [].push(jobNmae+"static_ips")
end

src_metadata= YAML.load_file(Dir.glob(src).first)
orig_src_metadata=Marshal.load(Marshal.dump(src_metadata))

releases=dependsReleases(getEle(src_metadata['job_types'],'router'))
             .push(*dependsReleases(getEle(src_metadata['job_types'],'diego_cell')))
             .push(*dependsReleases(getEle(src_metadata['job_types'],'ha_proxy'))).uniq;

releases.each {|relName|
  release =getEle(src_metadata['releases'],relName);

}



result_metadata = {}
result_metadata['name']=deploymentName
result_metadata['releases']=[];#src_metadata['releases']
releases.each {|relName|
  release =getEle(src_metadata['releases'],relName);
  puts release['file']
  result_metadata['releases'].push(release);
}

ARGV.each_with_index {|file, index|
  next if index <3
  name = file.to_s.split("-")[0]
  version = file.to_s.split("-")[1].split(".")[0]
  result_metadata['releases'].push({"name"=>name,"file"=>file,"version"=>version})
}

result_metadata['stemcell_criteria']=src_metadata['stemcell_criteria']
result_metadata['description']=src_metadata['description']
result_metadata['icon_image']=src_metadata['icon_image']
result_metadata['label']='Runtime For '+result_metadata['name']
result_metadata['metadata_version']=src_metadata['metadata_version']
result_metadata['product_version']=vversion
result_metadata['minimum_version_for_upgrade']="0.1"
result_metadata['rank']=80
result_metadata['serial']=src_metadata['serial']

result_metadata['job_types']=[]
result_metadata['job_types'].push(updateJobProperties(getEle(src_metadata['job_types'], 'router')))
result_metadata['job_types'].push(addKeepalivedProperties(updateJobProperties(getEle(src_metadata['job_types'], 'ha_proxy'))))
result_metadata['job_types'].push(addProperty(updateJobProperties(getEle(src_metadata['job_types'], 'diego_cell'))))
# result_metadata['job_types'].push(getEle(src_metadata['job_types'],'compilation')) #no compilation node in 1.8

keys = addPrefix(".router.",getConfigurable(getEle(orig_src_metadata['job_types'],'router')['property_blueprints'])).push(*commProp(".router."))
keys.push(*addPrefix(".diego_cell.",getConfigurable(getEle(orig_src_metadata['job_types'],'diego_cell')['property_blueprints']))).push(*commProp(".diego_cell."))
keys.push(*addPrefix(".ha_proxy.",getConfigurable(getEle(orig_src_metadata['job_types'],'ha_proxy')['property_blueprints']))).push(*commProp(".ha_proxy."))

result_metadata['form_types']=addInputs (updateForms orig_src_metadata['form_types'], keys)
File.open(result,'w') do |file|
  file.write result_metadata.to_yaml
end
